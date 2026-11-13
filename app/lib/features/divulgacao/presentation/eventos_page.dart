import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/comum.dart';
import '../../../models/categorias.dart';
import '../../../models/permissoes.dart';
import '../../../models/publicacao.dart';
import '../../comunidade/data/publicacoes_repository.dart';
import '../../comunidade/presentation/cartao_publicacao.dart';
import '../../identidade/data/identidade_repository.dart';

/// RF09 — eventos, projetos de extensão e iniciativas sociais. Os vencidos ficam em "Arquivados".
class EventosPage extends ConsumerStatefulWidget {
  const EventosPage({super.key});

  @override
  ConsumerState<EventosPage> createState() => _EventosPageState();
}

class _EventosPageState extends ConsumerState<EventosPage> {
  bool _arquivados = false;
  String? _categoria;

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider) as SessaoAtiva;
    final eventos = ref.watch(
      publicacoesProvider((
        tipo: TipoPublicacao.evento,
        status: _arquivados
            ? StatusPublicacao.arquivado
            : StatusPublicacao.aprovado,
        forumId: null,
        categoria: _categoria,
        ordenarPor: 'dataEvento',
        decrescente: _arquivados,
      )),
    );

    return Pagina(
      children: [
        CabecalhoPagina(
          titulo: 'Eventos e Projetos',
          subtitulo: 'Extensão, rodas de conversa, grupos de interesse e iniciativas sociais da UFJF',
          icone: Icons.event_outlined,
          acao: sessao.pode(Area.eventos, Acao.publicar)
              ? FilledButton.icon(
                  onPressed: () => context.go('/eventos/novo'),
                  icon: const Icon(Icons.add),
                  label: const Text('Divulgar'),
                )
              : null,
        ),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Próximos'),
              icon: Icon(Icons.upcoming_outlined),
            ),
            ButtonSegment(
              value: true,
              label: Text('Arquivados'),
              icon: Icon(Icons.inventory_2_outlined),
            ),
          ],
          selected: {_arquivados},
          onSelectionChanged: (s) => setState(() => _arquivados = s.first),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todas'),
              selected: _categoria == null,
              onSelected: (_) => setState(() => _categoria = null),
            ),
            for (final c in categoriasEvento)
              ChoiceChip(
                avatar: Icon(c.icone, size: 18),
                label: Text(c.label),
                selected: _categoria == c.id,
                onSelected: (_) => setState(() => _categoria = c.id),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AsyncView(
          value: eventos,
          data: (lista) {
            // Eventos que já passaram somem de "Próximos" mesmo antes do arquivamento diário (RF09).
            final agora = DateTime.now();
            final itens = lista
                .whereType<Evento>()
                .where((e) => _arquivados || e.dataEvento.isAfter(agora))
                .toList();
            if (itens.isEmpty) {
              return EstadoVazio(
                icone: Icons.event_busy_outlined,
                titulo: _arquivados
                    ? 'Nenhum evento arquivado'
                    : 'Nenhum evento programado',
              );
            }
            return LayoutBuilder(
              builder: (context, c) {
                final duas = c.maxWidth > 760;
                if (!duas) {
                  return Column(
                    children: [
                      for (final e in itens)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CartaoEvento(e),
                        ),
                    ],
                  );
                }
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final e in itens)
                      SizedBox(
                        width: (c.maxWidth - 12) / 2,
                        child: CartaoEvento(e),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}
