import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors.dart';
import '../../../core/widgets/acoes.dart';
import '../../../core/widgets/comum.dart';
import '../../../models/conteudo.dart';
import '../../../models/permissoes.dart';
import '../../../models/publicacao.dart';
import '../../identidade/data/identidade_repository.dart';
import '../data/moderacao_repository.dart';

/// Painel administrativo: moderação (RF07), denúncias (RF12), permissões (RF13) e logs (RNF15).
class AdminPage extends ConsumerWidget {
  const AdminPage({super.key, required this.aba});

  final String aba;

  static const _abas = [
    ('moderacao', 'Aprovação', Icons.fact_check_outlined),
    ('denuncias', 'Denúncias', Icons.flag_outlined),
    ('permissoes', 'Permissões', Icons.admin_panel_settings_outlined),
    ('logs', 'Logs e índices', Icons.receipt_long_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendentes = ref.watch(pendentesProvider).value?.length ?? 0;
    final denuncias = ref.watch(denunciasAbertasProvider).value?.length ?? 0;
    return Pagina(
      maxWidth: 1100,
      children: [
        const CabecalhoPagina(
          titulo: 'Administração',
          subtitulo: 'Moderação e gestão de acesso',
          icone: Icons.shield_outlined,
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            segments: [
              for (final (id, label, icone) in _abas)
                ButtonSegment(
                  value: id,
                  icon: Icon(icone),
                  label: Badge(
                    isLabelVisible:
                        (id == 'moderacao' && pendentes > 0) ||
                        (id == 'denuncias' && denuncias > 0),
                    label: Text('${id == 'moderacao' ? pendentes : denuncias}'),
                    offset: const Offset(14, -6),
                    child: Text(label),
                  ),
                ),
            ],
            selected: {aba},
            onSelectionChanged: (s) => context.go('/admin/${s.first}'),
          ),
        ),
        const SizedBox(height: 20),
        switch (aba) {
          'denuncias' => const _Denuncias(),
          'permissoes' => const _Permissoes(),
          'logs' => const _Logs(),
          _ => const _FilaModeracao(),
        },
      ],
    );
  }
}

class _FilaModeracao extends ConsumerWidget {
  const _FilaModeracao();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(pendentesProvider),
      data: (lista) {
        if (lista.isEmpty) {
          return const EstadoVazio(
            icone: Icons.task_alt,
            titulo: 'Não há conteúdos pendentes de revisão',
            mensagem: 'Publicações da comunidade externa aparecem aqui antes de ficarem visíveis.',
          );
        }
        return Column(children: [for (final p in lista) _ItemModeracao(p)]);
      },
    );
  }
}

class _ItemModeracao extends ConsumerStatefulWidget {
  const _ItemModeracao(this.p);

  final Publicacao p;

  @override
  ConsumerState<_ItemModeracao> createState() => _ItemModeracaoState();
}

class _ItemModeracaoState extends ConsumerState<_ItemModeracao> {
  bool _enviando = false;

  Future<void> _decidir(bool aprovar) async {
    String? motivo;
    if (!aprovar) {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Rejeitar publicação'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Motivo (será enviado ao autor)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Rejeitar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      motivo = controller.text.trim().isEmpty ? null : controller.text.trim();
    }
    setState(() => _enviando = true);
    try {
      await ref
          .read(moderacaoRepositoryProvider)
          .moderar(widget.p.id, aprovar: aprovar, motivo: motivo);
      if (mounted) {
        mostrarSucesso(
          context,
          aprovar
              ? 'Publicação aprovada e visível.'
              : 'Publicação rejeitada; o autor foi notificado.',
        );
      }
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TagChip(p.tipo.area.label, icone: p.tipo.area.icon),
                const SizedBox(width: 8),
                SeloPerfil(p.autorPerfil),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${p.autorNome} · ${tempoRelativo(p.createdAt)}',
                    style: t.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              p.titulo,
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            MarkdownBody(data: p.conteudo),
            if (p is Anuncio) ...[
              const SizedBox(height: 8),
              Text('Contato: ${p.contato}'),
            ],
            if (p.anexos.isNotEmpty) ...[
              const SizedBox(height: 8),
              ListaAnexos(p.anexos),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _enviando ? null : () => _decidir(false),
                  icon: const Icon(Icons.close),
                  label: const Text('Rejeitar'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _enviando ? null : () => _decidir(true),
                  icon: const Icon(Icons.check),
                  label: const Text('Aprovar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Denuncias extends ConsumerWidget {
  const _Denuncias();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AsyncView(
          value: ref.watch(denunciasAbertasProvider),
          data: (lista) {
            if (lista.isEmpty) {
              return const EstadoVazio(
                icone: Icons.verified_outlined,
                titulo: 'Nenhuma denúncia aberta',
              );
            }
            // Agrupa as denúncias do mesmo conteúdo.
            final porAlvo = <String, List<Denuncia>>{};
            for (final d in lista) {
              porAlvo.putIfAbsent(d.alvoPath, () => []).add(d);
            }
            return Column(
              children: [
                for (final grupo in porAlvo.values) _ItemDenuncia(grupo),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Resolvidas recentemente',
          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        AsyncView(
          value: ref.watch(denunciasResolvidasProvider),
          data: (lista) => lista.isEmpty
              ? const Text('Nenhuma ainda.')
              : Card(
                  child: Column(
                    children: [
                      for (final d in lista)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            d.decisao == 'remover'
                                ? Icons.delete_outline
                                : Icons.check,
                            size: 20,
                          ),
                          title: Text(d.alvoTitulo),
                          subtitle: Text(
                            '${d.motivo.label} · ${d.decisao == 'remover' ? 'Conteúdo removido' : 'Conteúdo mantido'}',
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _ItemDenuncia extends ConsumerStatefulWidget {
  const _ItemDenuncia(this.grupo);

  final List<Denuncia> grupo;

  @override
  ConsumerState<_ItemDenuncia> createState() => _ItemDenunciaState();
}

class _ItemDenunciaState extends ConsumerState<_ItemDenuncia> {
  bool _enviando = false;

  String? get _rota {
    final partes = widget.grupo.first.alvoPath.split('/');
    final tipo = widget.grupo.first.alvoTipo;
    if (partes.first == 'materiais') return '/materiais/item/${partes[1]}';
    final id = partes[1];
    return switch (tipo) {
      'topico' => '/foruns/topico/$id',
      'anuncio' => '/anuncios/$id',
      'evento' => '/eventos/$id',
      'orientacao' => '/orientacoes/$id',
      // Resposta denunciada: abre a discussão onde ela está.
      'resposta' => '/foruns/topico/$id',
      _ => null,
    };
  }

  Future<void> _resolver(bool remover) async {
    setState(() => _enviando = true);
    try {
      final n = await ref
          .read(moderacaoRepositoryProvider)
          .resolverDenuncia(widget.grupo.first.id, remover: remover);
      if (mounted) {
        mostrarSucesso(
          context,
          '${remover ? 'Conteúdo removido' : 'Conteúdo mantido'} · $n denúncia(s) resolvida(s).',
        );
      }
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final d = widget.grupo.first;
    final motivos = {for (final x in widget.grupo) x.motivo.label};
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TagChip(
                  '${widget.grupo.length} denúncia(s)',
                  cor: t.colorScheme.error,
                  icone: Icons.flag,
                ),
                const SizedBox(width: 8),
                TagChip(d.alvoTipo),
                const Spacer(),
                Text(tempoRelativo(d.createdAt), style: t.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              d.alvoTitulo,
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (d.alvoTrecho != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  d.alvoTrecho!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Motivos: ${motivos.join(', ')}',
              style: t.textTheme.bodyMedium,
            ),
            for (final x in widget.grupo.where((x) => x.detalhes.isNotEmpty))
              Text(
                '“${x.detalhes}”',
                style: t.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_rota != null)
                  TextButton.icon(
                    onPressed: () => context.go(_rota!),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ver conteúdo'),
                  ),
                OutlinedButton.icon(
                  onPressed: _enviando ? null : () => _resolver(false),
                  icon: const Icon(Icons.check),
                  label: const Text('Manter conteúdo'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: t.colorScheme.error,
                  ),
                  onPressed: _enviando ? null : () => _resolver(true),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remover conteúdo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// RF13 — matriz de permissões por perfil, aplicada em tempo real.
class _Permissoes extends ConsumerStatefulWidget {
  const _Permissoes();

  @override
  ConsumerState<_Permissoes> createState() => _PermissoesState();
}

class _PermissoesState extends ConsumerState<_Permissoes> {
  Permissoes? _rascunho;
  bool _salvando = false;

  Future<void> _salvar(Permissoes p) async {
    setState(() => _salvando = true);
    try {
      await ref.read(identidadeRepositoryProvider).salvarPermissoes(p);
      if (mounted) {
        setState(() => _rascunho = null);
        mostrarSucesso(
          context,
          'Permissões atualizadas. A mudança já vale para todos os usuários.',
        );
      }
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final atual = ref.watch(permissoesProvider).value ?? Permissoes.padrao;
    final p = _rascunho ?? atual;
    final conflitos = p.conflitos();
    final alterado = !p.igual(atual);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Defina o que cada perfil pode ler e publicar em cada área. Administradores têm acesso total.',
        ),
        const SizedBox(height: 12),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 32,
              columns: [
                const DataColumn(label: Text('Área')),
                for (final perfil in Permissoes.editaveis)
                  DataColumn(
                    label: Text(
                      perfil.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
              rows: [
                for (final area in Area.values)
                  DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            Icon(area.icon, size: 18),
                            const SizedBox(width: 8),
                            Text(area.label),
                          ],
                        ),
                      ),
                      for (final perfil in Permissoes.editaveis)
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final acao in Acao.values)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: FilterChip(
                                    label: Text(
                                      acao.label,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    selected: p.pode(perfil, area, acao),
                                    // Sem o ícone de check o chip mantém a largura fixa dentro da tabela.
                                    showCheckmark: false,
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (_) => setState(
                                      () => _rascunho = p.alternar(
                                        perfil,
                                        area,
                                        acao,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (conflitos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: t.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Configuração conflitante',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: t.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final c in conflitos)
                  Text(
                    '• $c',
                    style: TextStyle(color: t.colorScheme.onErrorContainer),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (alterado)
              TextButton(
                onPressed: () => setState(() => _rascunho = null),
                child: const Text('Descartar alterações'),
              ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => setState(() => _rascunho = Permissoes.padrao),
              child: const Text('Restaurar padrão'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: !alterado || conflitos.isNotEmpty || _salvando
                  ? null
                  : () => _salvar(p),
              icon: const Icon(Icons.save_outlined),
              label: Text(alterado ? 'Salvar alterações' : 'Sem alterações'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Logs extends ConsumerStatefulWidget {
  const _Logs();

  @override
  ConsumerState<_Logs> createState() => _LogsState();
}

class _LogsState extends ConsumerState<_Logs> {
  bool _atualizando = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Recalcular índices agora'),
            subtitle: const Text(
              'Atualiza as recomendações (RF10) e arquiva eventos vencidos (RF09). '
              'Executado automaticamente a cada hora e diariamente.',
            ),
            trailing: FilledButton.tonal(
              onPressed: _atualizando
                  ? null
                  : () async {
                      setState(() => _atualizando = true);
                      try {
                        final r = await ref
                            .read(moderacaoRepositoryProvider)
                            .atualizarIndices();
                        if (context.mounted) {
                          mostrarSucesso(
                            context,
                            'Índice com ${r['itens']} itens · ${r['arquivados']} evento(s) arquivado(s).',
                          );
                        }
                      } catch (e) {
                        if (context.mounted) mostrarErro(context, e);
                      } finally {
                        if (mounted) setState(() => _atualizando = false);
                      }
                    },
              child: _atualizando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Executar'),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Erros registrados pelos clientes',
          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        AsyncView(
          value: ref.watch(logsProvider),
          data: (logs) => logs.isEmpty
              ? const EstadoVazio(
                  icone: Icons.check_circle_outline,
                  titulo: 'Nenhum erro registrado',
                )
              : Card(
                  child: Column(
                    children: [
                      for (final l in logs)
                        ExpansionTile(
                          leading: const Icon(Icons.bug_report_outlined),
                          title: Text(
                            l['mensagem'] as String? ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${l['nivel']} · ${l['rota']} · ${l['plataforma']}'
                            '${l['createdAt'] is Timestamp ? ' · ${tempoRelativo((l['createdAt'] as Timestamp).toDate())}' : ''}',
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: SelectableText(
                                l['stack'] as String? ?? '',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
