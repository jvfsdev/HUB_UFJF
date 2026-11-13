import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/busca.dart';
import '../../../core/errors.dart';
import '../../../core/firebase.dart';
import '../../../models/conteudo.dart';
import '../../../models/usuario.dart';
import '../../identidade/data/identidade_repository.dart';

/// Módulo de Conteúdos: materiais de estudo (RF08), recomendações (RF10) e índices (RF15).
class ConteudosRepository {
  ConteudosRepository(this._db);

  final FirebaseFirestore _db;
  final _visualizados = <String>{};

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('materiais');

  Stream<List<MaterialEstudo>> porDisciplina(String disciplinaId) => _col
      .where('disciplinaId', isEqualTo: disciplinaId)
      .where('status', isEqualTo: 'aprovado')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(MaterialEstudo.fromDoc).toList());

  Stream<List<MaterialEstudo>> recentes({int limite = 12}) => _col
      .where('status', isEqualTo: 'aprovado')
      .orderBy('createdAt', descending: false)
      .limitToLast(limite)
      .snapshots()
      .map(
        (s) => s.docs.map(MaterialEstudo.fromDoc).toList().reversed.toList(),
      );

  Stream<MaterialEstudo?> observar(String id) => _col
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? MaterialEstudo.fromDoc(s) : null);

  Stream<List<MaterialEstudo>> meus(String uid) => _col
      .where('autorId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(MaterialEstudo.fromDoc).toList());

  Future<String> criar({
    required Usuario autor,
    required String titulo,
    required String descricao,
    required TipoMaterial tipo,
    required String disciplinaId,
    required String disciplinaNome,
    required String url,
    int? tamanho,
  }) async {
    if (titulo.trim().length < 3) {
      throw const AppException('O título deve ter pelo menos 3 caracteres.');
    }
    if (disciplinaId.isEmpty) {
      throw const AppException('Selecione a disciplina do material.');
    }
    if (url.isEmpty) {
      throw const AppException('Anexe um arquivo ou informe um link.');
    }
    if (tipo == TipoMaterial.link || tipo == TipoMaterial.video) {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
        throw const AppException(
          'Informe um link válido, começando com https://',
        );
      }
    }
    final ref = await _col.add({
      'titulo': titulo.trim(),
      'descricao': descricao.trim(),
      'tipo': tipo.name,
      'disciplinaId': disciplinaId,
      'disciplinaNome': disciplinaNome,
      'url': url,
      'tamanho': tamanho,
      'autorId': autor.uid,
      'autorNome': autor.nome,
      'status': autor.perfil == Perfil.externo ? 'pendente' : 'aprovado',
      'views': 0,
      'downloads': 0,
      'denunciasCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> remover(String id) =>
      _col.doc(id).update({'status': 'removido'});

  Future<void> registrarDownload(MaterialEstudo m, String uid) async {
    try {
      final batch = _db.batch()
        ..update(_col.doc(m.id), {'downloads': FieldValue.increment(1)})
        ..set(
          _db
              .collection('users')
              .doc(uid)
              .collection('interacoes')
              .doc('materiais'),
          {
            'total': FieldValue.increment(3),
            'atualizadoEm': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      await batch.commit();
    } catch (_) {}
  }

  Future<void> registrarVisualizacao(MaterialEstudo m, String uid) async {
    if (!_visualizados.add(m.id)) return;
    try {
      final batch = _db.batch()
        ..update(_col.doc(m.id), {'views': FieldValue.increment(1)})
        ..set(
          _db
              .collection('users')
              .doc(uid)
              .collection('interacoes')
              .doc('materiais'),
          {
            'total': FieldValue.increment(1),
            'atualizadoEm': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      await batch.commit();
    } catch (_) {}
  }

  Future<List<MaterialEstudo>> buscar(String consulta) async {
    final termo = termoDeBusca(consulta);
    if (termo == null) return const [];
    final snap = await _col
        .where('status', isEqualTo: 'aprovado')
        .where('keywords', arrayContains: termo)
        .limit(20)
        .get();
    return snap.docs
        .where(
          (d) => correspondeATodas(
            consulta,
            '${d['titulo']} ${d['disciplinaId']} ${d['disciplinaNome']}',
          ),
        )
        .map(MaterialEstudo.fromDoc)
        .toList();
  }

  /// RF15 — o índice de popularidade é lido do cache local quando disponível e só vai ao
  /// servidor quando o cache não existe ou está desatualizado (fluxos alternativos 1 e 2).
  Stream<List<ItemPopular>> indicePopular() => _db
      .collection('indices')
      .doc('popular')
      .snapshots()
      .map(
        (s) => [
          for (final m in (s.data()?['itens'] as List? ?? const []))
            ItemPopular.fromMap(Map<String, dynamic>.from(m)),
        ],
      );

  Stream<Map<String, int>> interacoes(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('interacoes')
      .snapshots()
      .map(
        (s) => {
          for (final d in s.docs)
            d.id: (d.data()['total'] as num?)?.toInt() ?? 0,
        },
      );
}

/// RF10 — ordena o índice popular pelo interesse do usuário em cada área.
/// Com histórico insuficiente (menos de 5 interações) usa apenas a popularidade geral.
List<ItemPopular> recomendar(
  List<ItemPopular> populares,
  Map<String, int> interacoes, {
  required bool Function(String area) podeVer,
  int limite = 10,
}) {
  final visiveis = populares.where((i) => podeVer(i.area)).toList();
  final total = interacoes.values.fold<int>(0, (a, b) => a + b);
  if (total < 5) return visiveis.take(limite).toList();
  double peso(ItemPopular i) =>
      i.score * (1 + 2 * ((interacoes[i.area] ?? 0) / total));
  visiveis.sort((a, b) => peso(b).compareTo(peso(a)));
  return visiveis.take(limite).toList();
}

final conteudosRepositoryProvider = Provider<ConteudosRepository>(
  (ref) => ConteudosRepository(ref.watch(firestoreProvider)),
);

final materiaisDisciplinaProvider = StreamProvider.autoDispose
    .family<List<MaterialEstudo>, String>(
      (ref, id) => ref.watch(conteudosRepositoryProvider).porDisciplina(id),
    );
final materiaisRecentesProvider =
    StreamProvider.autoDispose<List<MaterialEstudo>>(
      (ref) => ref.watch(conteudosRepositoryProvider).recentes(),
    );
final materialProvider = StreamProvider.autoDispose
    .family<MaterialEstudo?, String>(
      (ref, id) => ref.watch(conteudosRepositoryProvider).observar(id),
    );
final indicePopularProvider = StreamProvider<List<ItemPopular>>(
  (ref) => ref.watch(conteudosRepositoryProvider).indicePopular(),
);
final minhasInteracoesProvider = StreamProvider<Map<String, int>>((ref) {
  final u = ref.watch(usuarioAtualProvider);
  if (u == null) return Stream.value(const {});
  return ref.watch(conteudosRepositoryProvider).interacoes(u.uid);
});
