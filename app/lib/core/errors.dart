import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Erro de validação/regra de negócio com mensagem pronta para o usuário.
class AppException implements Exception {
  const AppException(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// RNF11 — traduz erros técnicos em mensagens claras e orientativas.
String mensagemErro(Object erro) {
  if (erro is AppException) return erro.mensagem;
  if (erro is FirebaseAuthException) {
    return switch (erro.code) {
      'email-already-in-use' =>
        'Este e-mail já está cadastrado. Faça login ou use outro e-mail.',
      'invalid-email' => 'O e-mail informado não é válido.',
      'weak-password' => 'A senha é fraca. Use pelo menos 8 caracteres, misturando letras e números.',
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        'E-mail ou senha incorretos. Confira os dados e tente novamente.',
      'too-many-requests' =>
        'Muitas tentativas seguidas. Aguarde alguns minutos e tente de novo.',
      'user-disabled' =>
        'Esta conta foi desativada. Procure a administração do HUB-UFJF.',
      'network-request-failed' =>
        'Sem conexão com a internet. Verifique sua rede.',
      'requires-recent-login' =>
        'Por segurança, saia e entre novamente antes de fazer isso.',
      _ => 'Não foi possível autenticar (${erro.code}).',
    };
  }
  if (erro is FirebaseFunctionsException) {
    // As functions já devolvem mensagens em português.
    return erro.message ?? 'Ocorreu um erro no servidor. Tente novamente.';
  }
  if (erro is FirebaseException) {
    return switch (erro.code) {
      'permission-denied' || 'unauthorized' =>
        'Você não tem permissão para esta ação com o seu perfil.',
      'unavailable' => 'Serviço indisponível no momento. Verifique sua conexão e tente novamente.',
      'not-found' || 'object-not-found' =>
        'O conteúdo não foi encontrado. Ele pode ter sido removido.',
      'already-exists' => 'Este registro já existe.',
      'canceled' => 'Operação cancelada.',
      'quota-exceeded' => 'Limite de uso atingido. Tente novamente mais tarde.',
      'failed-precondition' =>
        'A operação não pôde ser concluída agora. Recarregue a página.',
      _ => 'Ocorreu um erro inesperado (${erro.code}). Tente novamente.',
    };
  }
  if (erro is TimeoutException) {
    return 'A operação demorou demais. Verifique sua conexão.';
  }
  return 'Ocorreu um erro inesperado. Tente novamente.';
}

void mostrarErro(BuildContext context, Object erro) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensagemErro(erro)),
      backgroundColor: Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void mostrarSucesso(BuildContext context, String mensagem) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(mensagem), behavior: SnackBarBehavior.floating),
  );
}

/// RNF15 — registra erros não tratados na coleção `logs` (melhor esforço).
class LogService {
  static String rotaAtual = '/';
  static int _enviadosNaSessao = 0;

  static void instalar() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      registrar(details.exception, details.stack, nivel: 'flutter');
    };
    PlatformDispatcher.instance.onError = (erro, stack) {
      registrar(erro, stack, nivel: 'erro');
      return true;
    };
  }

  static Future<void> registrar(
    Object erro,
    StackTrace? stack, {
    String nivel = 'erro',
  }) async {
    debugPrint('[$nivel] $erro');
    if (_enviadosNaSessao >= 30) {
      return; // evita inundar a coleção em loops de erro
    }
    _enviadosNaSessao++;
    try {
      await FirebaseFirestore.instance.collection('logs').add({
        'nivel': nivel,
        'mensagem': erro.toString().substring(
          0,
          erro.toString().length.clamp(0, 4000),
        ),
        'stack': (stack?.toString() ?? '').substring(
          0,
          (stack?.toString() ?? '').length.clamp(0, 8000),
        ),
        'uid': FirebaseAuth.instance.currentUser?.uid,
        'rota': rotaAtual,
        'plataforma': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Sem rede ou sem permissão: o log fica só no console.
    }
  }
}
