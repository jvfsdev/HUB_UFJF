import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/comum.dart';

/// RNF05 — Política de Privacidade (LGPD, Lei nº 13.709/2018).
class PrivacidadePage extends StatelessWidget {
  const PrivacidadePage({super.key});

  static const _secoes = [
    (
      'Quais dados coletamos',
      'Nome, e-mail, perfil de acesso e, para estudantes que optarem, o curso e o histórico escolar importado. '
          'Também registramos interações agregadas por área (por exemplo, quantas vezes você acessou fóruns) para '
          'recomendar conteúdos.',
    ),
    (
      'Para que usamos',
      'Para autenticar você, aplicar as permissões do seu perfil, personalizar a grade curricular, recomendar '
          'conteúdos e moderar a plataforma. Não vendemos nem compartilhamos dados com terceiros.',
    ),
    (
      'Avaliações anônimas',
      'Avaliações de disciplinas, professores e projetos não guardam nenhuma informação que permita identificar '
          'quem as escreveu. O controle de "uma avaliação por item" usa um código irreversível, e a data é guardada '
          'sem horário.',
    ),
    (
      'Histórico escolar',
      'O PDF enviado fica em área privada, acessível somente a você. As disciplinas extraídas servem apenas para '
          'destacar sua situação na grade curricular.',
    ),
    (
      'Seus direitos',
      'Pelo seu perfil você pode, a qualquer momento, exportar todos os seus dados (portabilidade) e excluir sua '
          'conta. Na exclusão, seus dados pessoais são apagados e suas publicações permanecem sem o seu nome.',
    ),
    (
      'Segurança',
      'Senhas são armazenadas com hash pelo Firebase Authentication, o tráfego é criptografado (HTTPS) e o acesso '
          'aos dados é restrito por perfil diretamente no servidor.',
    ),
    (
      'Contato',
      'Dúvidas sobre privacidade podem ser enviadas à equipe do HUB-UFJF pelo e-mail privacidade@hub-ufjf.dev.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Política de Privacidade'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: Pagina(
        maxWidth: 760,
        children: [
          Text(
            'Como o HUB-UFJF trata seus dados',
            style: t.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Em conformidade com a Lei Geral de Proteção de Dados (Lei nº 13.709/2018).',
            style: t.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          for (final (titulo, texto) in _secoes) ...[
            Text(
              titulo,
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(texto, style: t.textTheme.bodyLarge?.copyWith(height: 1.5)),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
