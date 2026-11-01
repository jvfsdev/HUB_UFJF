import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Avaliação anônima (RF05). Não existe nenhum campo que identifique o autor (RNF04).
class Avaliacao {
  const Avaliacao({
    required this.id,
    required this.tipoAlvo,
    required this.alvoId,
    required this.nota,
    required this.comentario,
    required this.createdAt,
  });

  final String id;
  final String tipoAlvo;
  final String alvoId;
  final int nota;
  final String comentario;
  final DateTime createdAt;

  factory Avaliacao.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Avaliacao(
      id: doc.id,
      tipoAlvo: d['tipoAlvo'] as String? ?? '',
      alvoId: d['alvoId'] as String? ?? '',
      nota: (d['nota'] as num?)?.toInt() ?? 0,
      comentario: d['comentario'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

enum TipoMaterial {
  pdf('PDF', Icons.picture_as_pdf_outlined),
  video('Vídeo', Icons.play_circle_outline),
  prova('Prova antiga', Icons.assignment_outlined),
  link('Link', Icons.link);

  const TipoMaterial(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Material de estudo (RF08), com arquivo no Storage (RF11) ou link externo.
class MaterialEstudo {
  const MaterialEstudo({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.tipo,
    required this.disciplinaId,
    required this.disciplinaNome,
    required this.url,
    required this.autorId,
    required this.autorNome,
    required this.downloads,
    required this.views,
    required this.createdAt,
    this.tamanho,
    this.status = 'aprovado',
  });

  final String id;
  final String titulo;
  final String descricao;
  final TipoMaterial tipo;
  final String disciplinaId;
  final String disciplinaNome;
  final String url;
  final String? autorId;
  final String autorNome;
  final int downloads;
  final int views;
  final DateTime createdAt;
  final int? tamanho;
  final String status;

  String get path => 'materiais/$id';

  /// Id do vídeo quando o link é do YouTube, para exibir a miniatura.
  String? get youtubeId {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) return uri.pathSegments.firstOrNull;
    if (uri.host.contains('youtube.com')) return uri.queryParameters['v'];
    return null;
  }

  factory MaterialEstudo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return MaterialEstudo(
      id: doc.id,
      titulo: d['titulo'] as String? ?? '',
      descricao: d['descricao'] as String? ?? '',
      tipo: TipoMaterial.values.byName(d['tipo'] as String? ?? 'link'),
      disciplinaId: d['disciplinaId'] as String? ?? '',
      disciplinaNome: d['disciplinaNome'] as String? ?? '',
      url: d['url'] as String? ?? '',
      autorId: d['autorId'] as String?,
      autorNome: d['autorNome'] as String? ?? 'Anônimo',
      downloads: (d['downloads'] as num?)?.toInt() ?? 0,
      views: (d['views'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tamanho: (d['tamanho'] as num?)?.toInt(),
      status: d['status'] as String? ?? 'aprovado',
    );
  }
}

enum MotivoDenuncia {
  spam('Spam ou propaganda'),
  ofensivo('Conteúdo ofensivo ou discriminatório'),
  assedio('Assédio ou exposição de pessoas'),
  falso('Informação falsa ou golpe'),
  // O nome é o valor gravado no Firestore e validado pelas rules.
  // ignore: constant_identifier_names
  direitos_autorais('Violação de direitos autorais'),
  outro('Outro motivo');

  const MotivoDenuncia(this.label);
  final String label;
}

/// Denúncia de conteúdo (RF12).
class Denuncia {
  const Denuncia({
    required this.id,
    required this.alvoPath,
    required this.alvoTitulo,
    required this.alvoTipo,
    required this.motivo,
    required this.detalhes,
    required this.status,
    required this.createdAt,
    this.alvoTrecho,
    this.decisao,
  });

  final String id;
  final String alvoPath;
  final String alvoTitulo;
  final String alvoTipo;
  final MotivoDenuncia motivo;
  final String detalhes;
  final String status;
  final DateTime createdAt;
  final String? alvoTrecho;
  final String? decisao;

  factory Denuncia.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Denuncia(
      id: doc.id,
      alvoPath: d['alvoPath'] as String? ?? '',
      alvoTitulo: d['alvoTitulo'] as String? ?? '',
      alvoTipo: d['alvoTipo'] as String? ?? '',
      motivo: MotivoDenuncia.values.byName(d['motivo'] as String? ?? 'outro'),
      detalhes: d['detalhes'] as String? ?? '',
      status: d['status'] as String? ?? 'aberta',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      alvoTrecho: d['alvoTrecho'] as String?,
      decisao: d['decisao'] as String?,
    );
  }
}

class Notificacao {
  const Notificacao({
    required this.id,
    required this.tipo,
    required this.texto,
    required this.lida,
    required this.createdAt,
    this.link,
  });

  final String id;
  final String tipo;
  final String texto;
  final bool lida;
  final DateTime createdAt;
  final String? link;

  IconData get icone => switch (tipo) {
    'aprovacao' => Icons.check_circle_outline,
    'rejeicao' => Icons.cancel_outlined,
    'denuncia' => Icons.flag_outlined,
    'moderacao' => Icons.gavel_outlined,
    'resposta' => Icons.chat_bubble_outline,
    'orientacao' => Icons.support_agent_outlined,
    _ => Icons.notifications_none,
  };

  factory Notificacao.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Notificacao(
      id: doc.id,
      tipo: d['tipo'] as String? ?? '',
      texto: d['texto'] as String? ?? '',
      lida: d['lida'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      link: d['link'] as String?,
    );
  }
}

/// Item do índice de popularidade (`indices/popular`), usado nas recomendações (RF10).
class ItemPopular {
  const ItemPopular({
    required this.colecao,
    required this.id,
    required this.tipo,
    required this.area,
    required this.titulo,
    required this.resumo,
    required this.score,
    this.categoria,
    this.imagem,
  });

  final String colecao;
  final String id;
  final String tipo;
  final String area;
  final String titulo;
  final String resumo;
  final double score;
  final String? categoria;
  final String? imagem;

  String get rota => switch (tipo) {
    'topico' => '/foruns/topico/$id',
    'anuncio' => '/anuncios/$id',
    'evento' => '/eventos/$id',
    'orientacao' => '/orientacoes/$id',
    _ => '/materiais/item/$id',
  };

  factory ItemPopular.fromMap(Map<String, dynamic> m) => ItemPopular(
    colecao: m['colecao'] as String? ?? 'publicacoes',
    id: m['id'] as String,
    tipo: m['tipo'] as String? ?? 'topico',
    area: m['area'] as String? ?? 'foruns',
    titulo: m['titulo'] as String? ?? '',
    resumo: m['resumo'] as String? ?? '',
    score: (m['score'] as num?)?.toDouble() ?? 0,
    categoria: m['categoria'] as String?,
    imagem: m['imagem'] as String?,
  );
}
