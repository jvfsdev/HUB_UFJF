import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/firebase.dart';
import '../../../models/conteudo.dart';
import '../../../models/publicacao.dart';
import '../../comunidade/data/publicacoes_repository.dart';
import '../../identidade/data/identidade_repository.dart';

/// Módulo de Moderação: filtragem de conteúdo externo (RF07) e denúncias (RF12).
class ModeracaoRepository {
  ModeracaoRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  static String idDenuncia(String uid, String alvoPath) =>
      '${uid}__${alvoPath.replaceAll('/', '~')}';

  Future<bool> jaDenunciou(String uid, String alvoPath) async {
    final doc = await _db
        .collection('denuncias')
        .doc(idDenuncia(uid, alvoPath))
        .get();
    return doc.exists;
  }

  Future<void> denunciar({
    required String uid,
    required String alvoPath,
    required String alvoTipo,
    required String alvoTitulo,
    required MotivoDenuncia? motivo,
    String detalhes = '',
    String? trecho,
  }) async {
    if (motivo == null) {
      throw const AppException('Selecione o motivo da denúncia.');
    }
    // Fluxo alternativo 2: o conteúdo já pode ter sido removido.
    final alvo = await _db.doc(alvoPath).get();
    if (!alvo.exists || alvo.data()?['status'] == 'removido') {
      throw const AppException('Este conteúdo não está mais disponível.');
    }
    // Fluxo alternativo 1: denúncia duplicada.
    if (await jaDenunciou(uid, alvoPath)) {
      throw const AppException(
        'Você já denunciou este conteúdo. Ele está em análise pela moderação.',
      );
    }
    await _db.collection('denuncias').doc(idDenuncia(uid, alvoPath)).set({
      'denuncianteId': uid,
      'alvoPath': alvoPath,
      'alvoTipo': alvoTipo,
      'alvoTitulo': alvoTitulo,
      'alvoTrecho': trecho?.substring(0, trecho.length.clamp(0, 300)),
      'motivo': motivo.name,
      'detalhes': detalhes.trim(),
      'status': 'aberta',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Denuncia>> denunciasAbertas() => _db
      .collection('denuncias')
      .where('status', isEqualTo: 'aberta')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Denuncia.fromDoc).toList());

  Stream<List<Denuncia>> denunciasResolvidas() => _db
      .collection('denuncias')
      .where('status', isEqualTo: 'resolvida')
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .map((s) => s.docs.map(Denuncia.fromDoc).toList());

  Future<void> moderar(String id, {required bool aprovar, String? motivo}) =>
      _functions.httpsCallable('moderarPublicacao').call({
        'id': id,
        'decisao': aprovar ? 'aprovar' : 'rejeitar',
        'motivo': motivo,
      });

  Future<int> resolverDenuncia(
    String denunciaId, {
    required bool remover,
  }) async {
    final r = await _functions.httpsCallable('resolverDenuncia').call({
      'denunciaId': denunciaId,
      'decisao': remover ? 'remover' : 'manter',
    });
    return ((r.data as Map)['resolvidas'] as num).toInt();
  }

  Future<Map<String, dynamic>> atualizarIndices() async {
    final r = await _functions.httpsCallable('atualizarIndicesAgora').call();
    return Map<String, dynamic>.from(r.data as Map);
  }

  Stream<List<Map<String, dynamic>>> logs() => _db
      .collection('logs')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  Stream<List<Notificacao>> notificacoes(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('notificacoes')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(Notificacao.fromDoc).toList());

  Future<void> marcarLida(String uid, String id) => _db
      .collection('users')
      .doc(uid)
      .collection('notificacoes')
      .doc(id)
      .update({'lida': true});

  Future<void> marcarTodasLidas(String uid, List<Notificacao> lista) async {
    final batch = _db.batch();
    for (final n in lista.where((n) => !n.lida)) {
      batch.update(
        _db.collection('users').doc(uid).collection('notificacoes').doc(n.id),
        {'lida': true},
      );
    }
    await batch.commit();
  }
}

final moderacaoRepositoryProvider = Provider<ModeracaoRepository>(
  (ref) => ModeracaoRepository(
    ref.watch(firestoreProvider),
    ref.watch(functionsProvider),
  ),
);

final pendentesProvider = StreamProvider.autoDispose<List<Publicacao>>(
  (ref) => ref.watch(publicacoesRepositoryProvider).pendentes(),
);
final denunciasAbertasProvider = StreamProvider.autoDispose<List<Denuncia>>(
  (ref) => ref.watch(moderacaoRepositoryProvider).denunciasAbertas(),
);
final denunciasResolvidasProvider = StreamProvider.autoDispose<List<Denuncia>>(
  (ref) => ref.watch(moderacaoRepositoryProvider).denunciasResolvidas(),
);
final logsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(moderacaoRepositoryProvider).logs(),
);
final notificacoesProvider = StreamProvider<List<Notificacao>>((ref) {
  final u = ref.watch(usuarioAtualProvider);
  if (u == null) return Stream.value(const []);
  return ref.watch(moderacaoRepositoryProvider).notificacoes(u.uid);
});
