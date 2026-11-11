import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/comum.dart';
import '../../../models/categorias.dart';
import '../../../models/publicacao.dart';

String rotaDaPublicacao(Publicacao p) => switch (p) {
  Topico() => '/foruns/topico/${p.id}',
  Anuncio() => '/anuncios/${p.id}',
  Evento() => '/eventos/${p.id}',
  Orientacao() => '/orientacoes/${p.id}',
};

/// Card de listagem de tópicos e orientações.
class CartaoPublicacao extends StatelessWidget {
  const CartaoPublicacao(this.p, {super.key, this.mostrarArea = false});

  final Publicacao p;
  final bool mostrarArea;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(rotaDaPublicacao(p)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarUsuario(nome: p.autorNome, raio: 14),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      p.autorNome,
                      style: t.textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SeloPerfil(p.autorPerfil),
                  const Spacer(),
                  Text(
                    tempoRelativo(p.createdAt),
                    style: t.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (mostrarArea) ...[
                TagChip(p.tipo.area.label, icone: p.tipo.area.icon),
                const SizedBox(height: 6),
              ],
              Text(
                p.titulo,
                style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                p.conteudo.replaceAll(RegExp(r'[#*_>`]'), ''),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.bodyMedium?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              DefaultTextStyle.merge(
                style: t.textTheme.bodySmall,
                child: IconTheme.merge(
                  data: IconThemeData(
                    size: 16,
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline),
                      const SizedBox(width: 4),
                      Text('${p.respostasCount}'),
                      const SizedBox(width: 16),
                      const Icon(Icons.favorite_border),
                      const SizedBox(width: 4),
                      Text('${p.interacoes}'),
                      const SizedBox(width: 16),
                      const Icon(Icons.visibility_outlined),
                      const SizedBox(width: 4),
                      Text('${p.views}'),
                      if (p.anexos.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        const Icon(Icons.attach_file),
                        Text('${p.anexos.length}'),
                      ],
                      if (p is Orientacao && p.respostasCount == 0) ...[
                        const Spacer(),
                        const TagChip(
                          'Aguardando resposta',
                          cor: Color(0xFFEF6C00),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card visual de anúncio (RF06) com foto de capa.
class CartaoAnuncio extends StatelessWidget {
  const CartaoAnuncio(this.a, {super.key});

  final Anuncio a;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cat = categoriaPorId(categoriasAnuncio, a.categoria);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/anuncios/${a.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: a.imagemCapa != null
                  ? Image.network(
                      a.imagemCapa!.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _capa(cat),
                    )
                  : _capa(cat),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TagChip(cat.label, cor: cat.cor, icone: cat.icone),
                  const SizedBox(height: 8),
                  Text(
                    a.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (a.preco != null)
                        Text(
                          moeda(a.preco!),
                          style: t.textTheme.titleMedium?.copyWith(
                            color: t.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      else
                        Text('A combinar', style: t.textTheme.bodyMedium),
                      const Spacer(),
                      if (a.bairro != null)
                        Flexible(
                          child: Text(
                            a.bairro!,
                            style: t.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _capa(Categoria cat) => Container(
    color: cat.cor.withValues(alpha: 0.12),
    child: Icon(cat.icone, size: 48, color: cat.cor),
  );
}

/// Card de evento (RF09) com bloco de data.
class CartaoEvento extends StatelessWidget {
  const CartaoEvento(this.e, {super.key});

  final Evento e;

  static const _meses = [
    'JAN',
    'FEV',
    'MAR',
    'ABR',
    'MAI',
    'JUN',
    'JUL',
    'AGO',
    'SET',
    'OUT',
    'NOV',
    'DEZ',
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cat = categoriaPorId(categoriasEvento, e.categoria);
    final arquivado = e.status == StatusPublicacao.arquivado;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/eventos/${e.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: (arquivado ? Colors.grey : cat.cor).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${e.dataEvento.day}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: arquivado ? Colors.grey : cat.cor,
                      ),
                    ),
                    Text(
                      _meses[e.dataEvento.month - 1],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: arquivado ? Colors.grey : cat.cor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TagChip(cat.label, cor: cat.cor, icone: cat.icone),
                    const SizedBox(height: 6),
                    Text(
                      e.titulo,
                      style: t.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dataHoraFormatada(e.dataEvento),
                          style: t.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            e.local,
                            style: t.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
