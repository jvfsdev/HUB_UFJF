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

/// RF06 — anúncios de repúblicas, apostilas, jalecos e materiais.
class AnunciosPage extends ConsumerWidget {
  const AnunciosPage({super.key, this.categoria});

  final String? categoria;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider) as SessaoAtiva;
    final anuncios = ref.watch(
      publicacoesProvider((
        tipo: TipoPublicacao.anuncio,
        status: StatusPublicacao.aprovado,
        forumId: null,
        categoria: categoria,
        ordenarPor: 'createdAt',
        decrescente: true,
      )),
    );

    return Pagina(
      children: [
        CabecalhoPagina(
          titulo: 'Anúncios',
          subtitulo: 'Moradia e materiais entre a comunidade — o contato é direto com o anunciante',
          icone: Icons.storefront_outlined,
          acao: sessao.pode(Area.anuncios, Acao.publicar)
              ? FilledButton.icon(
                  onPressed: () => context.go('/anuncios/novo'),
                  icon: const Icon(Icons.add),
                  label: const Text('Anunciar'),
                )
              : null,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: categoria == null,
              onSelected: (_) => context.go('/anuncios'),
            ),
            for (final c in categoriasAnuncio)
              ChoiceChip(
                avatar: Icon(c.icone, size: 18),
                label: Text(c.label),
                selected: categoria == c.id,
                onSelected: (_) => context.go('/anuncios?categoria=${c.id}'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AsyncView(
          value: anuncios,
          data: (lista) {
            if (lista.isEmpty) {
              return EstadoVazio(
                icone: Icons.storefront_outlined,
                titulo: 'Nenhum anúncio nesta categoria',
                acao: sessao.pode(Area.anuncios, Acao.publicar)
                    ? FilledButton(
                        onPressed: () => context.go('/anuncios/novo'),
                        child: const Text('Criar anúncio'),
                      )
                    : null,
              );
            }
            return LayoutBuilder(
              builder: (context, c) {
                final colunas = (c.maxWidth / 280).floor().clamp(1, 4);
                return GridView.count(
                  crossAxisCount: colunas,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: colunas == 1 ? 1.05 : 0.98,
                  children: [
                    for (final a in lista.whereType<Anuncio>())
                      CartaoAnuncio(a),
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
