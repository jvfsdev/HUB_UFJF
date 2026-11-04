import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors.dart';
import '../../../models/usuario.dart';
import '../../academico/data/academico_repository.dart';
import '../data/identidade_repository.dart';

/// RF01 — cadastro com escolha de perfil. Também conclui cadastros interrompidos
/// (conta criada no Auth sem o documento de usuário).
class CadastroPage extends ConsumerStatefulWidget {
  const CadastroPage({super.key});

  @override
  ConsumerState<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends ConsumerState<CadastroPage> {
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  Perfil? _perfil;
  String? _cursoId;
  bool _consentimento = false;
  bool _carregando = false;
  List<String> _erros = const [];

  @override
  void initState() {
    super.initState();
    final sessao = ref.read(sessaoProvider);
    if (sessao is SessaoIncompleta) _email.text = sessao.user.email ?? '';
  }

  Future<void> _cadastrar() async {
    final incompleta = ref.read(sessaoProvider) is SessaoIncompleta;
    final erros = IdentidadeRepository.validarCadastro(
      nome: _nome.text,
      email: _email.text,
      // Num cadastro interrompido a senha já foi definida.
      senha: incompleta ? 'xxxxxxxx' : _senha.text,
      perfil: _perfil,
      consentimento: _consentimento,
    );
    setState(() => _erros = erros);
    if (erros.isNotEmpty) return;

    setState(() => _carregando = true);
    try {
      final repo = ref.read(identidadeRepositoryProvider);
      if (incompleta) {
        await repo.concluirCadastro(
          nome: _nome.text,
          perfil: _perfil!,
          cursoId: _cursoId,
          consentimento: _consentimento,
        );
      } else {
        await repo.cadastrar(
          nome: _nome.text,
          email: _email.text,
          senha: _senha.text,
          perfil: _perfil!,
          cursoId: _cursoId,
          consentimento: _consentimento,
        );
      }
      if (mounted && _perfil == Perfil.estudante) {
        mostrarSucesso(
          context,
          'Conta criada! Enviamos um link de confirmação para o seu e-mail institucional.',
        );
      }
    } catch (e) {
      setState(() => _erros = [mensagemErro(e)]);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final incompleta = ref.watch(sessaoProvider) is SessaoIncompleta;
    final cursos = ref.watch(cursosProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(incompleta ? 'Concluir cadastro' : 'Criar conta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (incompleta) await ref.read(identidadeRepositoryProvider).sair();
            if (context.mounted) context.go('/login');
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Como você se relaciona com a UFJF?',
                  style: t.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (final p in [
                  Perfil.estudante,
                  Perfil.geral,
                  Perfil.externo,
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _OpcaoPerfil(
                      perfil: p,
                      selecionado: _perfil == p,
                      onTap: () => setState(() => _perfil = p),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nome,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  enabled: !incompleta,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: const Icon(Icons.mail_outline),
                    helperText: _perfil == Perfil.estudante
                        ? 'Use seu e-mail institucional (${IdentidadeRepository.dominioEstudante})'
                        : null,
                  ),
                ),
                if (!incompleta) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _senha,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: Icon(Icons.lock_outline),
                      helperText: 'Mínimo de 8 caracteres',
                    ),
                  ),
                ],
                if (_perfil == Perfil.estudante && cursos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _cursoId,
                    decoration: const InputDecoration(
                      labelText: 'Seu curso (opcional)',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                    items: [
                      for (final c in cursos)
                        DropdownMenuItem(value: c.id, child: Text(c.rotulo)),
                    ],
                    onChanged: (v) => setState(() => _cursoId = v),
                  ),
                ],
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _consentimento,
                  onChanged: (v) => setState(() => _consentimento = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text.rich(
                    TextSpan(
                      text: 'Li e aceito a ',
                      children: [
                        TextSpan(
                          text: 'Política de Privacidade',
                          style: TextStyle(
                            color: t.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => context.push('/privacidade'),
                        ),
                        const TextSpan(
                          text:
                              ' e o tratamento dos meus dados conforme a LGPD.',
                        ),
                      ],
                    ),
                  ),
                ),
                if (_erros.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in _erros)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 18,
                                  color: t.colorScheme.onErrorContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    e,
                                    style: TextStyle(
                                      color: t.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _carregando ? null : _cadastrar,
                  child: _carregando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(incompleta ? 'Concluir cadastro' : 'Criar conta'),
                ),
                if (!incompleta)
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Já tenho conta'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpcaoPerfil extends StatelessWidget {
  const _OpcaoPerfil({
    required this.perfil,
    required this.selecionado,
    required this.onTap,
  });

  final Perfil perfil;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final icone = switch (perfil) {
      Perfil.estudante => Icons.school_outlined,
      Perfil.geral => Icons.badge_outlined,
      _ => Icons.explore_outlined,
    };
    return Card(
      color: selecionado ? t.colorScheme.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selecionado
              ? t.colorScheme.primary
              : t.colorScheme.outlineVariant,
          width: selecionado ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icone, color: selecionado ? t.colorScheme.primary : null),
        title: Text(
          perfil.label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(perfil.descricao),
        trailing: selecionado
            ? Icon(Icons.check_circle, color: t.colorScheme.primary)
            : null,
      ),
    );
  }
}
