import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/firebase.dart';
import '../../../models/academico.dart';
import '../../identidade/data/identidade_repository.dart';

/// Módulo Acadêmico: grade curricular (RF03) e importação de histórico (RF02).
class AcademicoRepository {
  AcademicoRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  static const tamanhoMaximoHistorico = 10 * 1024 * 1024;

  Stream<List<Curso>> cursos() => _db
      .collection('cursos')
      .orderBy('nome')
      .snapshots()
      .map((s) => s.docs.map(Curso.fromDoc).toList());

  Stream<List<Disciplina>> disciplinasDoCurso(String cursoId) => _db
      .collection('disciplinas')
      .where('periodoPorCurso.$cursoId', isGreaterThan: 0)
      .snapshots()
      .map((s) => s.docs.map(Disciplina.fromDoc).toList());

  Stream<List<Disciplina>> todasDisciplinas() => _db
      .collection('disciplinas')
      .orderBy('nome')
      .snapshots()
      .map((s) => s.docs.map(Disciplina.fromDoc).toList());

  Stream<HistoricoEscolar?> historico(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('historico')
      .doc('atual')
      .snapshots()
      .map((s) => s.exists ? HistoricoEscolar.fromMap(s.data()!) : null);

  /// RF02 — envia o PDF; a Cloud Function `onHistoricoUploaded` processa e grava o resultado.
  Stream<double> enviarHistorico(
    String uid,
    String nomeArquivo,
    Uint8List bytes,
  ) {
    if (!nomeArquivo.toLowerCase().endsWith('.pdf')) {
      throw const AppException(
        'Formato não suportado. Envie o histórico escolar em PDF, emitido pelo SIGA.',
      );
    }
    if (bytes.length > tamanhoMaximoHistorico) {
      throw const AppException(
        'O arquivo excede 10 MB. Envie o histórico oficial do SIGA, sem digitalizações.',
      );
    }
    final ref = _storage.ref(
      'historicos/$uid/historico_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    final task = ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/pdf'),
    );
    return task.snapshotEvents.map(
      (s) => s.totalBytes == 0 ? 0 : s.bytesTransferred / s.totalBytes,
    );
  }
}

final academicoRepositoryProvider = Provider<AcademicoRepository>(
  (ref) => AcademicoRepository(
    ref.watch(firestoreProvider),
    ref.watch(storageProvider),
  ),
);

final cursosProvider = StreamProvider<List<Curso>>(
  (ref) => ref.watch(academicoRepositoryProvider).cursos(),
);

final disciplinasDoCursoProvider =
    StreamProvider.family<List<Disciplina>, String>(
      (ref, cursoId) =>
          ref.watch(academicoRepositoryProvider).disciplinasDoCurso(cursoId),
    );

final todasDisciplinasProvider = StreamProvider<List<Disciplina>>(
  (ref) => ref.watch(academicoRepositoryProvider).todasDisciplinas(),
);

final meuHistoricoProvider = StreamProvider<HistoricoEscolar?>((ref) {
  final u = ref.watch(usuarioAtualProvider);
  if (u == null) return Stream.value(null);
  return ref.watch(academicoRepositoryProvider).historico(u.uid);
});
