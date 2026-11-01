import 'package:cloud_firestore/cloud_firestore.dart';

import 'permissoes.dart';
import 'usuario.dart';

enum TipoPublicacao {
  topico(Area.foruns),
  anuncio(Area.anuncios),
  evento(Area.eventos),
  orientacao(Area.orientacoes);

  const TipoPublicacao(this.area);
  final Area area;
}

enum StatusPublicacao {
  pendente('Aguardando aprovação'),
  aprovado('Publicado'),
  rejeitado('Rejeitado'),
  removido('Removido'),
  arquivado('Arquivado');

  const StatusPublicacao(this.label);
  final String label;
}

class Anexo {
  const Anexo({
    required this.nome,
    required this.url,
    required this.tipo,
    this.tamanho,
  });

  final String nome;
  final String url;

  /// `imagem`, `pdf` ou `video`.
  final String tipo;
  final int? tamanho;

  factory Anexo.fromMap(Map<String, dynamic> m) => Anexo(
    nome: m['nome'] as String? ?? 'arquivo',
    url: m['url'] as String? ?? '',
    tipo: m['tipo'] as String? ?? 'pdf',
    tamanho: m['tamanho'] as int?,
  );

  Map<String, dynamic> toMap() => {
    'nome': nome,
    'url': url,
    'tipo': tipo,
    'tamanho': tamanho,
  };
}

/// Classe abstrata `Publicacao` do diagrama de classes: atributos comuns a tópicos,
/// anúncios, eventos e orientações, incluindo o estado de aprovação (RF07, RF12).
sealed class Publicacao {
  Publicacao._fromMap(this.id, Map<String, dynamic> d)
    : titulo = d['titulo'] as String? ?? '',
      conteudo = d['conteudo'] as String? ?? '',
      autorId = d['autorId'] as String?,
      autorNome = d['autorNome'] as String? ?? 'Anônimo',
      autorPerfil =
          Perfil.fromName(d['autorPerfil'] as String?) ?? Perfil.geral,
      status = StatusPublicacao.values.byName(
        d['status'] as String? ?? 'aprovado',
      ),
      categoria = d['categoria'] as String?,
      anexos = [
        for (final a in (d['anexos'] as List? ?? const []))
          Anexo.fromMap(Map<String, dynamic>.from(a)),
      ],
      views = (d['views'] as num?)?.toInt() ?? 0,
      interacoes = (d['interacoes'] as num?)?.toInt() ?? 0,
      respostasCount = (d['respostasCount'] as num?)?.toInt() ?? 0,
      denunciasCount = (d['denunciasCount'] as num?)?.toInt() ?? 0,
      createdAt = (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      motivoModeracao = (d['moderacao'] as Map?)?['motivo'] as String?;

  final String id;
  final String titulo;
  final String conteudo;
  final String? autorId;
  final String autorNome;
  final Perfil autorPerfil;
  final StatusPublicacao status;
  final String? categoria;
  final List<Anexo> anexos;
  final int views;
  final int interacoes;
  final int respostasCount;
  final int denunciasCount;
  final DateTime createdAt;
  final String? motivoModeracao;

  TipoPublicacao get tipo;

  String get path => 'publicacoes/$id';

  Anexo? get imagemCapa => anexos.where((a) => a.tipo == 'imagem').firstOrNull;

  static Publicacao fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return switch (d['tipo']) {
      'anuncio' => Anuncio._(doc.id, d),
      'evento' => Evento._(doc.id, d),
      'orientacao' => Orientacao._(doc.id, d),
      _ => Topico._(doc.id, d),
    };
  }

  /// Campos comuns para criação; as rules exigem contadores zerados e o status correto.
  static Map<String, dynamic> novo({
    required TipoPublicacao tipo,
    required Usuario autor,
    required String titulo,
    required String conteudo,
    String? categoria,
    List<Anexo> anexos = const [],
    Map<String, dynamic> extras = const {},
  }) => {
    'tipo': tipo.name,
    'titulo': titulo.trim(),
    'conteudo': conteudo.trim(),
    'categoria': categoria,
    'anexos': [for (final a in anexos) a.toMap()],
    'autorId': autor.uid,
    'autorNome': autor.nome,
    'autorPerfil': autor.perfil.name,
    'status': autor.perfil == Perfil.externo ? 'pendente' : 'aprovado',
    'views': 0,
    'interacoes': 0,
    'respostasCount': 0,
    'denunciasCount': 0,
    'createdAt': FieldValue.serverTimestamp(),
    ...extras,
  };
}

/// Tópico de fórum temático (RF04).
class Topico extends Publicacao {
  Topico._(super.id, super.d)
    : forumId = d['forumId'] as String? ?? 'geral',
      super._fromMap();

  final String forumId;

  @override
  TipoPublicacao get tipo => TipoPublicacao.topico;
}

/// Anúncio de república, apostila, jaleco ou material (RF06).
class Anuncio extends Publicacao {
  Anuncio._(super.id, super.d)
    : contato = d['contato'] as String? ?? '',
      preco = (d['preco'] as num?)?.toDouble(),
      bairro = d['bairro'] as String?,
      super._fromMap();

  final String contato;
  final double? preco;
  final String? bairro;

  @override
  TipoPublicacao get tipo => TipoPublicacao.anuncio;
}

/// Evento, projeto de extensão ou iniciativa social (RF09).
class Evento extends Publicacao {
  Evento._(super.id, super.d)
    : dataEvento = (d['dataEvento'] as Timestamp?)?.toDate() ?? DateTime.now(),
      local = d['local'] as String? ?? '',
      projetoId = d['projetoId'] as String?,
      super._fromMap();

  final DateTime dataEvento;
  final String local;
  final String? projetoId;

  @override
  TipoPublicacao get tipo => TipoPublicacao.evento;
}

/// Pergunta da área de orientações para futuros alunos (RF14).
class Orientacao extends Publicacao {
  Orientacao._(super.id, super.d)
    : cursoInteresse = d['cursoInteresse'] as String?,
      super._fromMap();

  final String? cursoInteresse;

  @override
  TipoPublicacao get tipo => TipoPublicacao.orientacao;
}

class Resposta {
  const Resposta({
    required this.id,
    required this.publicacaoId,
    required this.conteudo,
    required this.autorId,
    required this.autorNome,
    required this.autorPerfil,
    required this.createdAt,
    this.cursoAutor,
  });

  final String id;
  final String publicacaoId;
  final String conteudo;
  final String? autorId;
  final String autorNome;
  final Perfil autorPerfil;
  final DateTime createdAt;
  final String? cursoAutor;

  String get path => 'publicacoes/$publicacaoId/respostas/$id';

  factory Resposta.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Resposta(
      id: doc.id,
      publicacaoId: doc.reference.parent.parent!.id,
      conteudo: d['conteudo'] as String? ?? '',
      autorId: d['autorId'] as String?,
      autorNome: d['autorNome'] as String? ?? 'Anônimo',
      autorPerfil: Perfil.fromName(d['autorPerfil'] as String?) ?? Perfil.geral,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      cursoAutor: d['cursoAutor'] as String?,
    );
  }
}
