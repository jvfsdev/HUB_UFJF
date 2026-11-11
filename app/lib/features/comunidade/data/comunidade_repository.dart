import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/firebase.dart';
import '../../../models/academico.dart';
import '../../../models/conteudo.dart';

class Forum {
  const Forum({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.icone,
    this.cor,
  });

  final String id;
  final String nome;
  final String descricao;
  final String icone;
  final int? cor;

  IconData get iconData => switch (icone) {
    'bus' => Icons.directions_bus_outlined,
    'restaurant' => Icons.restaurant_outlined,
    'school' => Icons.school_outlined,
    'reviews' => Icons.rate_review_outlined,
    'home' => Icons.home_work_outlined,
    'sports' => Icons.sports_soccer_outlined,
    _ => Icons.forum_outlined,
  };

  factory Forum.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Forum(
      id: doc.id,
      nome: d['nome'] as String? ?? doc.id,
      descricao: d['descricao'] as String? ?? '',
      icone: d['icone'] as String? ?? 'forum',
      cor: (d['cor'] as num?)?.toInt(),
    );
  }
}

/// Resultado do envio de uma avaliação (RF05).
sealed class ResultadoAvaliacao {
  const ResultadoAvaliacao();
}

class AvaliacaoRegistrada extends ResultadoAvaliacao {
  const AvaliacaoRegistrada({required this.editada});
  final bool editada;
}

/// Fluxo alternativo 1 — o estudante já avaliou este item; o app oferece a edição.
class AvaliacaoExistente extends ResultadoAvaliacao {
  const AvaliacaoExistente(this.nota, this.comentario);
  final int nota;
  final String comentario;
}

/// Módulo de Comunidade: fóruns (RF04) e avaliações anônimas (RF05).
class ComunidadeRepository {
  ComunidadeRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  Stream<List<Forum>> foruns() => _db
      .collection('foruns')
      .orderBy('ordem')
      .snapshots()
      .map((s) => s.docs.map(Forum.fromDoc).toList());

  Stream<List<Professor>> professores() => _db
      .collection('professores')
      .orderBy('nome')
      .snapshots()
      .map((s) => s.docs.map(Professor.fromDoc).toList());

  Stream<List<Projeto>> projetos() => _db
      .collection('projetos')
      .orderBy('nome')
      .snapshots()
      .map((s) => s.docs.map(Projeto.fromDoc).toList());

  Stream<Avaliavel?> alvo(String tipo, String id) {
    final colecao = switch (tipo) {
      'disciplina' => 'disciplinas',
      'professor' => 'professores',
      _ => 'projetos',
    };
    return _db.collection(colecao).doc(id).snapshots().map((s) {
      if (!s.exists) return null;
      return switch (tipo) {
        'disciplina' => Disciplina.fromDoc(s),
        'professor' => Professor.fromDoc(s),
        _ => Projeto.fromDoc(s),
      };
    });
  }

  Stream<List<Avaliacao>> avaliacoes(String tipoAlvo, String alvoId) => _db
      .collection('avaliacoes')
      .where('tipoAlvo', isEqualTo: tipoAlvo)
      .where('alvoId', isEqualTo: alvoId)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(Avaliacao.fromDoc).toList());

  Future<ResultadoAvaliacao> avaliar({
    required String tipoAlvo,
    required String alvoId,
    required int nota,
    required String comentario,
    bool editar = false,
  }) async {
    if (nota < 1 || nota > 5) {
      throw const AppException('Escolha uma nota de 1 a 5 estrelas.');
    }
    if (comentario.length > 1000) {
      throw const AppException(
        'O comentário não pode exceder 1000 caracteres.',
      );
    }
    final r = await _functions.httpsCallable('enviarAvaliacao').call({
      'tipoAlvo': tipoAlvo,
      'alvoId': alvoId,
      'nota': nota,
      'comentario': comentario,
      'editar': editar,
    });
    final data = Map<String, dynamic>.from(r.data as Map);
    if (data['jaAvaliado'] == true) {
      return AvaliacaoExistente(
        (data['nota'] as num).toInt(),
        data['comentario'] as String? ?? '',
      );
    }
    return AvaliacaoRegistrada(editada: data['editada'] == true);
  }
}

final comunidadeRepositoryProvider = Provider<ComunidadeRepository>(
  (ref) => ComunidadeRepository(
    ref.watch(firestoreProvider),
    ref.watch(functionsProvider),
  ),
);

final forunsProvider = StreamProvider<List<Forum>>(
  (ref) => ref.watch(comunidadeRepositoryProvider).foruns(),
);
final professoresProvider = StreamProvider<List<Professor>>(
  (ref) => ref.watch(comunidadeRepositoryProvider).professores(),
);
final projetosProvider = StreamProvider<List<Projeto>>(
  (ref) => ref.watch(comunidadeRepositoryProvider).projetos(),
);

final alvoAvaliacaoProvider = StreamProvider.autoDispose
    .family<Avaliavel?, (String, String)>(
      (ref, a) => ref.watch(comunidadeRepositoryProvider).alvo(a.$1, a.$2),
    );
final avaliacoesProvider = StreamProvider.autoDispose
    .family<List<Avaliacao>, (String, String)>(
      (ref, a) =>
          ref.watch(comunidadeRepositoryProvider).avaliacoes(a.$1, a.$2),
    );
