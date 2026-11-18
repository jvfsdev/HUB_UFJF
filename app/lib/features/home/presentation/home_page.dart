import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/comum.dart';
import '../../../models/conteudo.dart';
import '../../../models/permissoes.dart';
import '../../../models/publicacao.dart';
import '../../../models/usuario.dart';
import '../../academico/data/academico_repository.dart';
import '../../comunidade/data/publicacoes_repository.dart';
import '../../comunidade/presentation/cartao_publicacao.dart';
import '../../conteudos/data/conteudos_repository.dart';
import '../../identidade/data/identidade_repository.dart';

/// Página inicial com recomendações (RF10) e atalhos para os módulos.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider) as SessaoAtiva;
    final u = sessao.usuario;
    final t = Theme.of(context);
    final populares = ref.watch(indicePopularProvider);
    final interacoes = ref.watch(minhasInteracoesProvider).value ?? const {};
    final proximosEventos = sessao.pode(Area.eventos)
        ? ref.watch(
            publicacoesProvider((
              tipo: TipoPublicacao.evento,
              status: StatusPublicacao.aprovado,
              forumId: null,
              categoria: null,
              ordenarPor: 'dataEvento',
              decrescente: false,
            )),
          )
        : null;
    final historico = u.perfil == Perfil.estudante
        ? ref.watch(meuHistoricoProvider).value
        : null;

    final atalhos = [
      for (final a in [
        Area.grade,
        Area.foruns,
        Area.materiais,
        Area.avaliacoes,
        Area.anuncios,
        Area.eventos,
        Area.orientacoes,
      ])
        if (sessao.pode(a)) a,
    ];

    return Pagina(
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B3D91), Color(0xFF1756C8)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Olá, ${u.primeiroNome}! 👋',
                style: t.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(switch (u.perfil) {
                Perfil.estudante when historico == null => 'Importe seu histórico do SIGA para ver sua grade personalizada e o que você já pode cursar.',
                Perfil.estudante => 'Veja o que está rolando na UFJF e o que recomendamos para você hoje.',
                Perfil.admin => 'Painel de moderação disponível no menu Admin.',
                _ => 'Veja o que está rolando na comunidade da UFJF.',
              }, style: const TextStyle(color: Colors.white70, fontSize: 15)),
              if (u.perfil == Perfil.estudante && historico == null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ambarUfjf,
                    foregroundColor: Colors.black87,
                  ),
                  onPressed: () => context.go('/grade/historico'),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importar histórico'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final a in atalhos)
              ActionChip(
                avatar: Icon(a.icon, size: 18),
                label: Text(a.label),
                onPressed: () => context.go(switch (a) {
                  Area.foruns => '/foruns',
                  Area.anuncios => '/anuncios',
                  Area.eventos => '/eventos',
                  Area.materiais => '/materiais',
                  Area.grade => '/grade',
                  Area.avaliacoes => '/avaliacoes',
                  Area.orientacoes => '/orientacoes',
                }),
              ),
          ],
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, c) {
            final recomendacoes = _Recomendacoes(
              itens: populares,
              interacoes: interacoes,
              podeVer: (area) =>
                  Area.values.where((a) => a.name == area).any(sessao.pode),
            );
            final eventos = proximosEventos == null
                ? null
                : _ProximosEventos(proximosEventos);
            if (c.maxWidth < 900 || eventos == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  recomendacoes,
                  if (eventos != null) ...[const SizedBox(height: 28), eventos],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: recomendacoes),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: eventos),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Recomendacoes extends StatelessWidget {
  const _Recomendacoes({
    required this.itens,
    required this.interacoes,
    required this.podeVer,
  });

  final AsyncValue<List<ItemPopular>> itens;
  final Map<String, int> interacoes;
  final bool Function(String) podeVer;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final total = interacoes.values.fold<int>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: ambarUfjf),
            const SizedBox(width: 8),
            Text(
              total < 5 ? 'Em alta na comunidade' : 'Recomendado para você',
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        if (total < 5)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Explore a plataforma para receber recomendações personalizadas.',
              style: t.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 12),
        AsyncView(
          value: itens,
          data: (lista) {
            final recomendados = recomendar(
              lista,
              interacoes,
              podeVer: podeVer,
            );
            if (recomendados.isEmpty) {
              return const EstadoVazio(
                icone: Icons.explore_outlined,
                titulo: 'Ainda não há conteúdo suficiente para recomendar',
                mensagem: 'Explore os fóruns, materiais e eventos — e contribua também!',
              );
            }
            return Column(
              children: [
                for (final i in recomendados)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      onTap: () => context.go(i.rota),
                      leading: i.imagem != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                i.imagem!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _icone(i),
                              ),
                            )
                          : _icone(i),
                      title: Text(
                        i.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        i.resumo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: context.isMobile
                          ? null
                          : TagChip(
                              Area.values
                                  .firstWhere(
                                    (a) => a.name == i.area,
                                    orElse: () => Area.foruns,
                                  )
                                  .label,
                            ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _icone(ItemPopular i) {
    final area = Area.values.firstWhere(
      (a) => a.name == i.area,
      orElse: () => Area.foruns,
    );
    return CircleAvatar(radius: 24, child: Icon(area.icon));
  }
}

class _ProximosEventos extends StatelessWidget {
  const _ProximosEventos(this.eventos);

  final AsyncValue<List<Publicacao>> eventos;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.event, color: azulUfjf),
            const SizedBox(width: 8),
            Text(
              'Próximos eventos',
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.go('/eventos'),
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        AsyncView(
          value: eventos,
          data: (lista) {
            final proximos = lista
                .whereType<Evento>()
                .where((e) => e.dataEvento.isAfter(DateTime.now()))
                .take(4)
                .toList();
            return proximos.isEmpty
                ? const EstadoVazio(
                    icone: Icons.event_busy_outlined,
                    titulo: 'Nenhum evento programado',
                  )
                : Column(
                    children: [
                      for (final e in proximos)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CartaoEvento(e),
                        ),
                    ],
                  );
          },
        ),
      ],
    );
  }
}
