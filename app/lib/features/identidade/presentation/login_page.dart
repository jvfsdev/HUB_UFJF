import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors.dart';
import '../../../core/firebase.dart';
import '../../../core/theme.dart';
import '../data/identidade_repository.dart';

/// Contas semeadas para a apresentação (ver seed/seed.ts).
const contasDemo = [
  ('Ana (ingressante)', 'ana.estudante@estudante.ufjf.br', Icons.school),
  (
    'Bruno (veterano)',
    'bruno.veterano@estudante.ufjf.br',
    Icons.workspace_premium_outlined,
  ),
  ('Carla (prestadora)', 'carla@prestador.com', Icons.badge_outlined),
  (
    'Diego (vestibulando)',
    'diego.vestibulando@gmail.com',
    Icons.explore_outlined,
  ),
  ('Administração', 'admin@hub-ufjf.dev', Icons.shield_outlined),
];
const senhaDemo = 'HubUfjf@2026';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _carregando = false;
  bool _ocultar = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    // Somente em builds para o Emulator Suite: `?demo=bruno` entra direto com a conta demo
    // (usado nas capturas automatizadas de tela).
    final demo = Uri.base.queryParameters['demo'];
    if (usarEmuladores && demo != null) {
      final conta = contasDemo.where((c) => c.$2.startsWith(demo)).firstOrNull;
      if (conta != null) {
        _email.text = conta.$2;
        _senha.text = senhaDemo;
        WidgetsBinding.instance.addPostFrameCallback((_) => _entrar());
      }
    }
  }

  Future<void> _entrar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await ref
          .read(identidadeRepositoryProvider)
          .entrar(_email.text, _senha.text);
    } catch (e) {
      setState(() => _erro = mensagemErro(e));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _recuperar() async {
    try {
      await ref.read(identidadeRepositoryProvider).recuperarSenha(_email.text);
      if (mounted) {
        mostrarSucesso(
          context,
          'Enviamos um link de redefinição para ${_email.text.trim()}.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemErro(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final form = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Entrar',
              style: t.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Acesse com seu e-mail e senha.',
              style: t.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              onSubmitted: (_) => _entrar(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _senha,
              obscureText: _ocultar,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _ocultar
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _ocultar = !_ocultar),
                ),
              ),
              onSubmitted: (_) => _entrar(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _recuperar,
                child: const Text('Esqueci minha senha'),
              ),
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _erro!,
                  style: TextStyle(color: t.colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: _carregando ? null : _entrar,
              child: _carregando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Entrar'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/cadastro'),
              child: const Text('Criar conta'),
            ),
            const SizedBox(height: 28),
            Text('Contas de demonstração', style: t.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (nome, email, icone) in contasDemo)
                  ActionChip(
                    avatar: Icon(icone, size: 18),
                    label: Text(nome),
                    onPressed: () {
                      _email.text = email;
                      _senha.text = senhaDemo;
                      _entrar();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final largo = c.maxWidth >= 900;
          return Row(
            children: [
              if (largo) const Expanded(child: _Apresentacao()),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        if (!largo) ...[
                          const _MarcaGrande(escura: true),
                          const SizedBox(height: 32),
                        ],
                        form,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MarcaGrande extends StatelessWidget {
  const _MarcaGrande({this.escura = false});

  final bool escura;

  @override
  Widget build(BuildContext context) {
    final cor = escura ? azulUfjf : Colors.white;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: escura ? azulUfjf : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'HUB',
            style: TextStyle(
              color: escura ? Colors.white : azulUfjf,
              fontWeight: FontWeight.w900,
              fontSize: 28,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'UFJF',
          style: TextStyle(
            color: cor,
            fontWeight: FontWeight.w900,
            fontSize: 28,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _Apresentacao extends StatelessWidget {
  const _Apresentacao();

  @override
  Widget build(BuildContext context) {
    const itens = [
      (
        Icons.account_tree_outlined,
        'Grade curricular e pré-requisitos com o seu histórico',
      ),
      (Icons.forum_outlined, 'Fóruns sobre circular, RU, cursos e moradia'),
      (Icons.star_outline, 'Avaliações anônimas de disciplinas e professores'),
      (
        Icons.menu_book_outlined,
        'Materiais de estudo, provas antigas e vídeos',
      ),
      (Icons.home_work_outlined, 'Repúblicas, apostilas e jalecos'),
      (Icons.event_outlined, 'Projetos de extensão e eventos'),
    ];
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3D91), Color(0xFF062457)],
        ),
      ),
      padding: const EdgeInsets.all(56),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MarcaGrande(),
          const SizedBox(height: 32),
          const Text(
            'Tudo o que você precisa para começar bem na UFJF, em um só lugar.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          for (final (icone, texto) in itens)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Icon(icone, color: ambarUfjf),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      texto,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
