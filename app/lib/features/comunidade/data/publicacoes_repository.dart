import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/busca.dart';
import '../../../core/errors.dart';
import '../../../core/firebase.dart';
import '../../../models/publicacao.dart';
import '../../../models/usuario.dart';

/// Acesso à coleção `publicacoes` (tópicos, anúncios, eventos e orientações) e às respostas.
class PublicacoesRepository {
  PublicacoesRepository(this._db);

  final FirebaseFirestore _db;
  static const limiteConteudo = 5000;

  /// Itens já contabilizados nesta sessão, para não inflar as visualizações (RF10).
  final _visualizados = <String>{};

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('publicacoes');

  Stream<List<Publicacao>> listar({
    required TipoPublicacao tipo,
    StatusPublicacao status = StatusPublicacao.aprovado,
    String? forumId,
    String? categoria,
    String ordenarPor = 'createdAt',
    bool decrescente = true,
    int limite = 30,
  }) {
    Query<Map<String, dynamic>> q = _col
        .where('tipo', isEqualTo: tipo.name)
        .where('status', isEqualTo: status.name);
    if (forumId != null) q = q.where('forumId', isEqualTo: forumId);
    if (categoria != null) q = q.where('categoria', isEqualTo: categoria);
    return q
        .orderBy(ordenarPor, descending: decrescente)
        .limit(limite)
        .snapshots()
        .map((s) => s.docs.map(Publicacao.fromDoc).toList());
  }

  Stream<Publicacao?> observar(String id) => _col
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? Publicacao.fromDoc(s) : null);

  Stream<List<Publicacao>> minhas(String uid) => _col
      .where('autorId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(Publicacao.fromDoc).toList());

  /// Fila de moderação (RF07) — apenas administradores conseguem ler.
  Stream<List<Publicacao>> pendentes() => _col
      .where('status', isEqualTo: StatusPublicacao.pendente.name)
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(Publicacao.fromDoc).toList());

  static void validar({required String titulo, required String conteudo}) {
    if (titulo.trim().length < 3) {
      throw const AppException('O título deve ter pelo menos 3 caracteres.');
    }
    if (titulo.trim().length > 200) {
      throw const AppException('O título deve ter no máximo 200 caracteres.');
    }
    if (conteudo.trim().isEmpty) {
      throw const AppException('Escreva o conteúdo antes de publicar.');
    }
    if (conteudo.length > limiteConteudo) {
      throw const AppException(
        'O conteúdo não pode exceder $limiteConteudo caracteres.',
      );
    }
  }

  /// Cria a publicação. Para usuários externos ela nasce pendente (RF07).
  Future<String> criar({
    required TipoPublicacao tipo,
    required Usuario autor,
    required String titulo,
    required String conteudo,
    String? categoria,
    List<Anexo> anexos = const [],
    Map<String, dynamic> extras = const {},
  }) async {
    validar(titulo: titulo, conteudo: conteudo);
    final ref = await _col.add(
      Publicacao.novo(
        tipo: tipo,
        autor: autor,
        titulo: titulo,
        conteudo: conteudo,
        categoria: categoria,
        anexos: anexos,
        extras: extras,
      ),
    );
    return ref.id;
  }

  Future<void> remover(String id) =>
      _col.doc(id).update({'status': StatusPublicacao.removido.name});

  Stream<List<Resposta>> respostas(String publicacaoId) => _col
      .doc(publicacaoId)
      .collection('respostas')
      .where('status', isEqualTo: 'aprovado')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(Resposta.fromDoc).toList());

  Future<void> responder(
    String publicacaoId,
    Usuario autor,
    String conteudo, {
    String? cursoAutor,
  }) async {
    if (conteudo.trim().isEmpty) {
      throw const AppException('Escreva sua resposta antes de enviar.');
    }
    if (conteudo.length > limiteConteudo) {
      throw const AppException(
        'A resposta não pode exceder $limiteConteudo caracteres.',
      );
    }
    await _col.doc(publicacaoId).collection('respostas').add({
      'conteudo': conteudo.trim(),
      'autorId': autor.uid,
      'autorNome': autor.nome,
      'autorPerfil': autor.perfil.name,
      'cursoAutor': cursoAutor,
      'status': 'aprovado',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removerResposta(String path) =>
      _db.doc(path).update({'status': 'removido'});

  /// RF10 — registra a visualização (uma por sessão) e o interesse do usuário pela área.
  Future<void> registrarVisualizacao(Publicacao p, String uid) async {
    if (p.status != StatusPublicacao.aprovado || !_visualizados.add(p.id)) {
      return;
    }
    try {
      final batch = _db.batch()
        ..update(_col.doc(p.id), {'views': FieldValue.increment(1)})
        ..set(
          _db
              .collection('users')
              .doc(uid)
              .collection('interacoes')
              .doc(p.tipo.area.name),
          {
            'total': FieldValue.increment(1),
            'atualizadoEm': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      await batch.commit();
    } catch (_) {
      // Contagem de visualizações é melhor esforço.
    }
  }

  Stream<bool> curtido(String publicacaoId, String uid) => _col
      .doc(publicacaoId)
      .collection('curtidas')
      .doc(uid)
      .snapshots()
      .map((s) => s.exists);

  Future<void> alternarCurtida(
    Publicacao p,
    String uid, {
    required bool curtir,
  }) async {
    final batch = _db.batch();
    final curtida = _col.doc(p.id).collection('curtidas').doc(uid);
    if (curtir) {
      batch.set(curtida, {'em': FieldValue.serverTimestamp()});
      batch.set(
        _db
            .collection('users')
            .doc(uid)
            .collection('interacoes')
            .doc(p.tipo.area.name),
        {
          'total': FieldValue.increment(3),
          'atualizadoEm': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } else {
      batch.delete(curtida);
    }
    batch.update(_col.doc(p.id), {
      'interacoes': FieldValue.increment(curtir ? 1 : -1),
    });
    await batch.commit();
  }

  /// RF15 — busca pelos prefixos indexados em `keywords`, uma consulta por tipo
  /// (as Security Rules exigem o tipo para verificar a permissão de leitura da área).
  Future<List<Publicacao>> buscar(
    String consulta,
    Iterable<TipoPublicacao> tipos,
  ) async {
    final termo = termoDeBusca(consulta);
    if (termo == null) return const [];
    final resultados = await Future.wait(
      tipos.map(
        (tipo) => _col
            .where('tipo', isEqualTo: tipo.name)
            .where('status', isEqualTo: StatusPublicacao.aprovado.name)
            .where('keywords', arrayContains: termo)
            .limit(20)
            .get(),
      ),
    );
    return [
      for (final snap in resultados)
        for (final doc in snap.docs)
          if (correspondeATodas(
            consulta,
            '${doc.data()['titulo']} ${doc.data()['categoria'] ?? ''} '
            '${doc.data()['local'] ?? ''} ${doc.data()['autorNome'] ?? ''}',
          ))
            Publicacao.fromDoc(doc),
    ];
  }
}

final publicacoesRepositoryProvider = Provider<PublicacoesRepository>(
  (ref) => PublicacoesRepository(ref.watch(firestoreProvider)),
);

typedef FiltroPublicacoes = ({
  TipoPublicacao tipo,
  StatusPublicacao status,
  String? forumId,
  String? categoria,
  String ordenarPor,
  bool decrescente,
});

final publicacoesProvider = StreamProvider.autoDispose
    .family<List<Publicacao>, FiltroPublicacoes>(
      (ref, f) => ref
          .watch(publicacoesRepositoryProvider)
          .listar(
            tipo: f.tipo,
            status: f.status,
            forumId: f.forumId,
            categoria: f.categoria,
            ordenarPor: f.ordenarPor,
            decrescente: f.decrescente,
          ),
    );

final publicacaoProvider = StreamProvider.autoDispose
    .family<Publicacao?, String>(
      (ref, id) => ref.watch(publicacoesRepositoryProvider).observar(id),
    );

final respostasProvider = StreamProvider.autoDispose
    .family<List<Resposta>, String>(
      (ref, id) => ref.watch(publicacoesRepositoryProvider).respostas(id),
    );
