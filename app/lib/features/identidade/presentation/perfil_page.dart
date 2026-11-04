import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors.dart';
import '../../../core/widgets/comum.dart';
import '../../../models/conteudo.dart';
import '../../../models/publicacao.dart';
import '../../../models/usuario.dart';
import '../../academico/data/academico_repository.dart';
import '../../comunidade/data/publicacoes_repository.dart';
import '../../conteudos/data/conteudos_repository.dart';
import '../data/identidade_repository.dart';

final _minhasPublicacoesProvider = StreamProvider.autoDispose<List<Publicacao>>(
  (ref) {
    final u = ref.watch(usuarioAtualProvider);
    if (u == null) return Stream.value(const []);
    return ref.watch(publicacoesRepositoryProvider).minhas(u.uid);
  },
);

final _meusMateriaisProvider = StreamProvider.autoDispose<List<MaterialEstudo>>(
  (ref) {
    final u = ref.watch(usuarioAtualProvider);
    if (u == null) return Stream.value(const []);
    return ref.watch(conteudosRepositoryProvider).meus(u.uid);
  },
);

class PerfilPage extends ConsumerWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider) as SessaoAtiva;
    final u = sessao.usuario;
    final t = Theme.of(context);
    final cursos = ref.watch(cursosProvider).value ?? const [];
    final curso = cursos.where((c) => c.id == u.cursoId).firstOrNull;

    return Pagina(
      maxWidth: 860,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                AvatarUsuario(nome: u.nome, raio: 36),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.nome,
                        style: t.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(u.email, style: t.textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          SeloPerfil(u.perfil),
                          if (curso != null)
                            TagChip(curso.rotulo, icone: Icons.school_outlined),
                          if (u.perfil == Perfil.estudante &&
                              !sessao.emailVerificado)
                            const TagChip(
                              'E-mail não verificado',
                              cor: Color(0xFFEF6C00),
                              icone: Icons.mark_email_unread_outlined,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar dados',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _EditarPerfil(usuario: u),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (u.perfil == Perfil.estudante) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Histórico escolar'),
              subtitle: Text(switch (ref.watch(meuHistoricoProvider).value) {
                null => 'Importe seu histórico do SIGA para personalizar a grade curricular.',
                final h when h.status == 'ok' =>
                  '${h.disciplinas.length} disciplinas importadas'
                      '${h.ira != null ? ' • IRA ${h.ira!.toStringAsFixed(1)}' : ''}',
                final h when h.status == 'erro' =>
                  'Falha na última importação: ${h.erro}',
                _ => 'Processando...',
              }),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/grade/historico'),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Minhas publicações',
          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        AsyncView(
          value: ref.watch(_minhasPublicacoesProvider),
          data: (lista) => lista.isEmpty
              ? const Card(
                  child: ListTile(title: Text('Você ainda não publicou nada.')),
                )
              : Card(
                  child: Column(
                    children: [
                      for (final p in lista)
                        ListTile(
                          leading: Icon(p.tipo.area.icon),
                          title: Text(p.titulo),
                          subtitle: Text(
                            '${p.tipo.area.label} • ${tempoRelativo(p.createdAt)}'
                            '${p.status == StatusPublicacao.rejeitado && p.motivoModeracao != null ? ' • Motivo: ${p.motivoModeracao}' : ''}',
                          ),
                          trailing: _StatusChip(p.status),
                          onTap: p.status == StatusPublicacao.removido
                              ? null
                              : () => context.go(_rota(p)),
                        ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 16),
        AsyncView(
          value: ref.watch(_meusMateriaisProvider),
          data: (lista) => lista.isEmpty
              ? const SizedBox.shrink()
              : Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Text(
                          'Materiais que compartilhei',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      for (final m in lista)
                        ListTile(
                          leading: Icon(m.tipo.icon),
                          title: Text(m.titulo),
                          subtitle: Text(
                            '${m.disciplinaId} • ${m.downloads} downloads • ${m.views} visualizações',
                          ),
                          onTap: () => context.go('/materiais/item/${m.id}'),
                        ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 24),
        Text(
          'Privacidade e dados (LGPD)',
          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Exportar meus dados'),
                subtitle: const Text(
                  'Baixe uma cópia de todos os dados pessoais que guardamos sobre você.',
                ),
                onTap: () => _exportar(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Política de Privacidade'),
                onTap: () => context.go('/privacidade'),
              ),
              if (u.perfil != Perfil.admin) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: t.colorScheme.error,
                  ),
                  title: Text(
                    'Excluir minha conta',
                    style: TextStyle(color: t.colorScheme.error),
                  ),
                  subtitle: const Text(
                    'Remove seus dados pessoais. Suas publicações ficam anônimas.',
                  ),
                  onTap: () => _excluir(context, ref),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _rota(Publicacao p) => switch (p) {
    Topico() => '/foruns/topico/${p.id}',
    Anuncio() => '/anuncios/${p.id}',
    Evento() => '/eventos/${p.id}',
    Orientacao() => '/orientacoes/${p.id}',
  };

  Future<void> _exportar(BuildContext context, WidgetRef ref) async {
    try {
      final dados = await ref
          .read(identidadeRepositoryProvider)
          .exportarDados();
      final json = const JsonEncoder.withIndent('  ').convert(dados);
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Seus dados'),
          content: SizedBox(
            width: 600,
            height: 420,
            child: SingleChildScrollView(
              child: SelectableText(
                json,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: json));
                mostrarSucesso(
                  context,
                  'Dados copiados para a área de transferência.',
                );
              },
              child: const Text('Copiar JSON'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) mostrarErro(context, e);
    }
  }

  Future<void> _excluir(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir conta?'),
        content: const Text(
          'Seus dados pessoais, histórico e notificações serão apagados definitivamente. '
          'Publicações e respostas permanecem, mas sem o seu nome. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir definitivamente'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(identidadeRepositoryProvider).excluirConta();
    } catch (e) {
      if (context.mounted) mostrarErro(context, e);
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final StatusPublicacao status;

  @override
  Widget build(BuildContext context) {
    final cor = switch (status) {
      StatusPublicacao.aprovado => const Color(0xFF2E7D32),
      StatusPublicacao.pendente => const Color(0xFFEF6C00),
      StatusPublicacao.arquivado => Colors.grey,
      _ => Theme.of(context).colorScheme.error,
    };
    return TagChip(status.label, cor: cor);
  }
}

class _EditarPerfil extends ConsumerStatefulWidget {
  const _EditarPerfil({required this.usuario});

  final Usuario usuario;

  @override
  ConsumerState<_EditarPerfil> createState() => _EditarPerfilState();
}

class _EditarPerfilState extends ConsumerState<_EditarPerfil> {
  late final _nome = TextEditingController(text: widget.usuario.nome);
  late String? _cursoId = widget.usuario.cursoId;

  @override
  Widget build(BuildContext context) {
    final cursos = ref.watch(cursosProvider).value ?? const [];
    return AlertDialog(
      title: const Text('Editar dados'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nome,
              decoration: const InputDecoration(labelText: 'Nome completo'),
            ),
            if (widget.usuario.perfil == Perfil.estudante) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: cursos.any((c) => c.id == _cursoId)
                    ? _cursoId
                    : null,
                decoration: const InputDecoration(labelText: 'Curso'),
                items: [
                  for (final c in cursos)
                    DropdownMenuItem(value: c.id, child: Text(c.rotulo)),
                ],
                onChanged: (v) => setState(() => _cursoId = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await ref
                  .read(identidadeRepositoryProvider)
                  .atualizarPerfil(
                    widget.usuario.uid,
                    nome: _nome.text,
                    cursoId: _cursoId,
                  );
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              if (context.mounted) mostrarErro(context, e);
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
