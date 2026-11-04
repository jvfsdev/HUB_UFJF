import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/firebase.dart';
import '../../../models/permissoes.dart';
import '../../../models/usuario.dart';

/// Módulo de Identidade e Acesso (RF01, RF13).
class IdentidadeRepository {
  IdentidadeRepository(this._auth, this._db, this._functions);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  static final _emailValido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const dominioEstudante = '@estudante.ufjf.br';

  Future<void> entrar(String email, String senha) async {
    if (!_emailValido.hasMatch(email.trim())) {
      throw const AppException('Informe um e-mail válido.');
    }
    if (senha.isEmpty) throw const AppException('Informe sua senha.');
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: senha,
    );
  }

  /// RF01 — validação dos dados (fluxo alternativo 2) antes de criar a conta.
  static List<String> validarCadastro({
    required String nome,
    required String email,
    required String senha,
    required Perfil? perfil,
    required bool consentimento,
  }) {
    final erros = <String>[];
    if (nome.trim().length < 3) erros.add('Informe seu nome completo.');
    if (!_emailValido.hasMatch(email.trim())) {
      erros.add('Informe um e-mail válido.');
    }
    if (senha.length < 8) erros.add('A senha deve ter no mínimo 8 caracteres.');
    if (perfil == null) erros.add('Selecione um perfil.');
    if (perfil == Perfil.estudante &&
        !email.trim().toLowerCase().endsWith(dominioEstudante)) {
      erros.add(
        'O perfil Estudante exige e-mail institucional ($dominioEstudante).',
      );
    }
    if (!consentimento) {
      erros.add('É necessário aceitar a Política de Privacidade.');
    }
    return erros;
  }

  Future<void> cadastrar({
    required String nome,
    required String email,
    required String senha,
    required Perfil perfil,
    required bool consentimento,
    String? cursoId,
  }) async {
    final erros = validarCadastro(
      nome: nome,
      email: email,
      senha: senha,
      perfil: perfil,
      consentimento: consentimento,
    );
    if (erros.isNotEmpty) throw AppException(erros.join('\n'));

    // Se a conta de autenticação já existe mas o cadastro não foi concluído, reaproveita.
    final atual = _auth.currentUser;
    if (atual == null ||
        atual.email?.toLowerCase() != email.trim().toLowerCase()) {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: senha,
      );
    }
    await concluirCadastro(
      nome: nome,
      perfil: perfil,
      cursoId: cursoId,
      consentimento: consentimento,
    );
  }

  Future<void> concluirCadastro({
    required String nome,
    required Perfil perfil,
    required bool consentimento,
    String? cursoId,
  }) async {
    final user = _auth.currentUser!;
    await _functions.httpsCallable('completarCadastro').call({
      'nome': nome.trim(),
      'perfil': perfil.name,
      'cursoId': cursoId,
      'consentimentoLGPD': consentimento,
    });
    // Força a renovação do token para que a custom claim `role` chegue às Security Rules.
    await user.getIdToken(true);
    if (perfil == Perfil.estudante && !user.emailVerified) {
      await user.sendEmailVerification().catchError((_) {});
    }
  }

  Future<void> recuperarSenha(String email) async {
    if (!_emailValido.hasMatch(email.trim())) {
      throw const AppException('Informe o e-mail da sua conta.');
    }
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sair() => _auth.signOut();

  Future<void> atualizarPerfil(
    String uid, {
    required String nome,
    String? cursoId,
  }) async {
    if (nome.trim().length < 3) {
      throw const AppException('Informe seu nome completo.');
    }
    await _db.collection('users').doc(uid).update({
      'nome': nome.trim(),
      'cursoId': cursoId,
    });
  }

  Future<Map<String, dynamic>> exportarDados() async {
    final r = await _functions.httpsCallable('exportarDados').call();
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> excluirConta() async {
    await _functions.httpsCallable('excluirConta').call();
    await _auth.signOut();
  }

  Stream<Usuario?> observarUsuario(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? Usuario.fromDoc(s) : null);

  Stream<Permissoes> observarPermissoes() => _db
      .collection('config')
      .doc('permissoes')
      .snapshots()
      .map((s) => Permissoes.fromMap(s.data()));

  Future<void> salvarPermissoes(Permissoes p) async {
    final conflitos = p.conflitos();
    if (conflitos.isNotEmpty) throw AppException(conflitos.first);
    await _db.collection('config').doc('permissoes').set({
      ...p.toMap(),
      'atualizadoEm': FieldValue.serverTimestamp(),
      'atualizadoPor': _auth.currentUser?.uid,
    });
  }
}

final identidadeRepositoryProvider = Provider<IdentidadeRepository>(
  (ref) => IdentidadeRepository(
    ref.watch(authProvider),
    ref.watch(firestoreProvider),
    ref.watch(functionsProvider),
  ),
);

/// Usuário do Firebase Auth (o stream de token captura mudanças de custom claims).
final authUserProvider = StreamProvider<User?>(
  (ref) => ref.watch(authProvider).idTokenChanges(),
);

/// Estado da sessão usado pelo router e pelas telas.
sealed class Sessao {
  const Sessao();
}

class SessaoCarregando extends Sessao {
  const SessaoCarregando();
}

class SessaoDeslogada extends Sessao {
  const SessaoDeslogada();
}

/// Autenticado no Firebase, mas sem o cadastro concluído (sem documento `users/{uid}`).
class SessaoIncompleta extends Sessao {
  const SessaoIncompleta(this.user);
  final User user;
}

class SessaoAtiva extends Sessao {
  const SessaoAtiva(
    this.usuario,
    this.permissoes, {
    required this.emailVerificado,
  });
  final Usuario usuario;
  final Permissoes permissoes;
  final bool emailVerificado;

  bool pode(Area area, [Acao acao = Acao.ler]) =>
      permissoes.pode(usuario.perfil, area, acao);
}

final _usuarioDocProvider = StreamProvider<Usuario?>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(identidadeRepositoryProvider).observarUsuario(user.uid);
});

final permissoesProvider = StreamProvider<Permissoes>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return Stream.value(Permissoes.padrao);
  return ref.watch(identidadeRepositoryProvider).observarPermissoes();
});

final sessaoProvider = Provider<Sessao>((ref) {
  final auth = ref.watch(authUserProvider);
  if (auth.isLoading && !auth.hasValue) return const SessaoCarregando();
  final user = auth.value;
  if (user == null) return const SessaoDeslogada();

  final doc = ref.watch(_usuarioDocProvider);
  if (!doc.hasValue) return const SessaoCarregando();
  final usuario = doc.value;
  if (usuario == null) return SessaoIncompleta(user);

  final permissoes = ref.watch(permissoesProvider).value ?? Permissoes.padrao;
  return SessaoAtiva(usuario, permissoes, emailVerificado: user.emailVerified);
});

/// Atalho para telas que só existem com sessão ativa.
final usuarioAtualProvider = Provider<Usuario?>((ref) {
  final s = ref.watch(sessaoProvider);
  return s is SessaoAtiva ? s.usuario : null;
});
