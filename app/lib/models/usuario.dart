import 'package:cloud_firestore/cloud_firestore.dart';

/// Perfis de usuário do HUB-UFJF (Requisitos de Usuário, Figura 1).
enum Perfil {
  estudante('Estudante', 'Aluno regularmente matriculado na UFJF'),
  geral(
    'Usuário Geral',
    'Servidores, prestadores de serviço e demais membros da comunidade',
  ),
  externo(
    'Comunidade Externa',
    'Ainda não matriculado: vestibulandos e interessados',
  ),
  admin('Administrador', 'Moderação e gestão da plataforma');

  const Perfil(this.label, this.descricao);
  final String label;
  final String descricao;

  static Perfil? fromName(String? name) =>
      Perfil.values.where((p) => p.name == name).firstOrNull;
}

class Usuario {
  const Usuario({
    required this.uid,
    required this.nome,
    required this.email,
    required this.perfil,
    this.cursoId,
    this.matricula,
    this.createdAt,
  });

  final String uid;
  final String nome;
  final String email;
  final Perfil perfil;
  final String? cursoId;
  final String? matricula;
  final DateTime? createdAt;

  String get iniciais {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  String get primeiroNome => nome.trim().split(' ').first;

  factory Usuario.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Usuario(
      uid: doc.id,
      nome: d['nome'] as String? ?? '',
      email: d['email'] as String? ?? '',
      perfil: Perfil.fromName(d['perfil'] as String?) ?? Perfil.geral,
      cursoId: d['cursoId'] as String?,
      matricula: d['matricula'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
