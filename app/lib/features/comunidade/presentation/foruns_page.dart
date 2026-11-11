import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/comum.dart';
import '../../../models/permissoes.dart';
import '../../../models/publicacao.dart';
import '../../identidade/data/identidade_repository.dart';
import '../data/comunidade_repository.dart';
import '../data/publicacoes_repository.dart';
import 'cartao_publicacao.dart';

/// RF04 — lista de fóruns temáticos.
class ForunsPage extends ConsumerWidget {
  const ForunsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentes = ref.watch(
      publicacoesProvider((
        tipo: TipoPublicacao.topico,
        status: StatusPublicacao.aprovado,
        forumId: null,
        categoria: null,
        ordenarPor: 'createdAt',
        decrescente: true,
      )),
    );
    return Pagina(
      children: [
        const CabecalhoPagina(
          titulo: 'Fóruns',
          subtitulo:
              'Converse com veteranos, calouros e prestadores de serviço',
          icone: Icons.forum_outlined,
        ),
        AsyncView(
          value: ref.watch(forunsProvider),
          data: (foruns) => LayoutBuilder(
            builder: (context, c) {
              final colunas = c.maxWidth > 900 ? 3 : (c.maxWidth > 560 ? 2 : 1);
              return GridView.count(
                crossAxisCount: colunas,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: colunas == 1 ? 3.6 : 2.4,
                children: [
                  for (final f in foruns)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.go('/foruns/${f.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Color(f.cor ?? 0xFF0B3D91)
                                    .withValues(alpha: 0.12),
                                child: Icon(
                                  f.iconData,
                                  color: Color(f.cor ?? 0xFF0B3D91),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f.nome,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      f.descricao,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Discussões recentes',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        AsyncView(
          value: recentes,
          data: (lista) => Column(
            children: [
              for (final p in lista.take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CartaoPublicacao(p),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// RF04 — tópicos de um fórum, atualizados em tempo real (RNF03).
class ForumPage extends ConsumerStatefulWidget {
  const ForumPage({super.key, required this.forumId});

  final String forumId;

  @override
  ConsumerState<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends ConsumerState<ForumPage> {
  String _ordem = 'createdAt';

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider) as SessaoAtiva;
    final forum = ref
        .watch(forunsProvider)
        .value
        ?.where((f) => f.id == widget.forumId)
        .firstOrNull;
    final topicos = ref.watch(
      publicacoesProvider((
        tipo: TipoPublicacao.topico,
        status: StatusPublicacao.aprovado,
        forumId: widget.forumId,
        categoria: null,
        ordenarPor: _ordem,
        decrescente: true,
      )),
    );

    return Pagina(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/foruns'),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Todos os fóruns'),
          ),
        ),
        CabecalhoPagina(
          titulo: forum?.nome ?? 'Fórum',
          subtitulo: forum?.descricao,
          icone: forum?.iconData ?? Icons.forum_outlined,
          acao: sessao.pode(Area.foruns, Acao.publicar)
              ? FilledButton.icon(
                  onPressed: () => context.go('/foruns/${widget.forumId}/novo'),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo tópico'),
                )
              : null,
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'createdAt',
              label: Text('Recentes'),
              icon: Icon(Icons.schedule),
            ),
            ButtonSegment(
              value: 'interacoes',
              label: Text('Populares'),
              icon: Icon(Icons.local_fire_department_outlined),
            ),
          ],
          selected: {_ordem},
          onSelectionChanged: (s) => setState(() => _ordem = s.first),
        ),
        const SizedBox(height: 16),
        AsyncView(
          value: topicos,
          data: (lista) => lista.isEmpty
              ? EstadoVazio(
                  icone: Icons.forum_outlined,
                  titulo: 'Nenhum tópico ainda',
                  mensagem: 'Seja o primeiro a puxar assunto neste fórum.',
                  acao: sessao.pode(Area.foruns, Acao.publicar)
                      ? FilledButton(
                          onPressed: () =>
                              context.go('/foruns/${widget.forumId}/novo'),
                          child: const Text('Criar tópico'),
                        )
                      : null,
                )
              : Column(
                  children: [
                    for (final p in lista)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CartaoPublicacao(p),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
