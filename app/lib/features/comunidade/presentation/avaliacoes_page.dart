import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/busca.dart';
import '../../../core/errors.dart';
import '../../../core/widgets/comum.dart';
import '../../../models/academico.dart';
import '../../../models/categorias.dart';
import '../../../models/permissoes.dart';
import '../../academico/data/academico_repository.dart';
import '../../identidade/data/identidade_repository.dart';
import '../data/comunidade_repository.dart';

/// RF05 — catálogo de disciplinas, professores e projetos avaliáveis.
class AvaliacoesPage extends ConsumerStatefulWidget {
  const AvaliacoesPage({super.key, this.aba});

  final String? aba;

  @override
  ConsumerState<AvaliacoesPage> createState() => _AvaliacoesPageState();
}

class _AvaliacoesPageState extends ConsumerState<AvaliacoesPage> {
  late String _aba = widget.aba ?? 'professor';
  String _filtro = '';
  String _ordem = 'nota';

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Avaliavel>> itens = switch (_aba) {
      'disciplina' => ref.watch(todasDisciplinasProvider),
      'projeto' => ref.watch(projetosProvider),
      _ => ref.watch(professoresProvider),
    };
    return Pagina(
      children: [
        const CabecalhoPagina(
          titulo: 'Avaliações',
          subtitulo: 'Opiniões anônimas de estudantes sobre disciplinas, professores e projetos',
          icone: Icons.star_outline,
        ),
        const AvisoStatus(
          icone: Icons.verified_user_outlined,
          cor: Color(0xFF2E7D32),
          texto: 'Avaliações são 100% anônimas: nenhuma informação do autor é armazenada junto da avaliação.',
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'professor',
              label: Text('Professores'),
              icon: Icon(Icons.person_outline),
            ),
            ButtonSegment(
              value: 'disciplina',
              label: Text('Disciplinas'),
              icon: Icon(Icons.class_outlined),
            ),
            ButtonSegment(
              value: 'projeto',
              label: Text('Projetos'),
              icon: Icon(Icons.diversity_3_outlined),
            ),
          ],
          selected: {_aba},
          onSelectionChanged: (s) => setState(() => _aba = s.first),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Filtrar por nome ou código',
                ),
                onChanged: (v) => setState(() => _filtro = v),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _ordem,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: 'nota',
                  child: Text('Melhor avaliados'),
                ),
                DropdownMenuItem(value: 'total', child: Text('Mais avaliados')),
                DropdownMenuItem(value: 'nome', child: Text('Nome (A–Z)')),
              ],
              onChanged: (v) => setState(() => _ordem = v!),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AsyncView(
          value: itens,
          data: (lista) {
            final filtrada =
                lista
                    .where(
                      (i) =>
                          _filtro.isEmpty ||
                          normalizar('${i.nome} ${i.id}')
                              .contains(normalizar(_filtro)),
                    )
                    .toList()
                  ..sort(
                    (a, b) => switch (_ordem) {
                      'total' => b.totalAvaliacoes.compareTo(a.totalAvaliacoes),
                      'nome' => a.nome.compareTo(b.nome),
                      _ => b.mediaAvaliacao.compareTo(a.mediaAvaliacao),
                    },
                  );
            if (filtrada.isEmpty) {
              return const EstadoVazio(
                icone: Icons.search_off,
                titulo: 'Nada encontrado',
              );
            }
            return Card(
              child: Column(
                children: [
                  for (final (i, item) in filtrada.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      onTap: () =>
                          context.go('/avaliacoes/${item.tipoAlvo}/${item.id}'),
                      leading: AvatarUsuario(nome: item.nome),
                      title: Text(
                        item.nome,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(switch (item) {
                        Professor(:final departamento) => departamento,
                        Disciplina(:final id, :final departamento) =>
                          '$id • $departamento',
                        Projeto(:final categoria, :final coordenador) => [
                          categoriaPorId(categoriasProjeto, categoria).label,
                          if (coordenador.isNotEmpty) coordenador,
                        ].join(' • '),
                        _ => '',
                      }),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.totalAvaliacoes == 0
                                    ? '–'
                                    : item.mediaAvaliacao.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFF2A900),
                                size: 18,
                              ),
                            ],
                          ),
                          Text(
                            '${item.totalAvaliacoes} avaliações',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// RF05 — página de um item com resumo das notas, comentários e formulário de avaliação.
class AvaliacaoDetalhePage extends ConsumerWidget {
  const AvaliacaoDetalhePage({super.key, required this.tipo, required this.id});

  final String tipo;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider) as SessaoAtiva;
    final t = Theme.of(context);
    return AsyncView(
      value: ref.watch(alvoAvaliacaoProvider((tipo, id))),
      data: (alvo) {
        if (alvo == null) {
          return const EstadoVazio(
            icone: Icons.search_off,
            titulo: 'Item não encontrado',
          );
        }
        return Pagina(
          maxWidth: 860,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go('/avaliacoes?aba=$tipo'),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Avaliações'),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Wrap(
                  spacing: 32,
                  runSpacing: 20,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TagChip(switch (tipo) {
                            'disciplina' => 'Disciplina',
                            'professor' => 'Professor(a)',
                            _ => 'Projeto',
                          }),
                          const SizedBox(height: 8),
                          Text(
                            alvo.nome,
                            style: t.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(switch (alvo) {
                            Professor(
                              :final departamento,
                              :final disciplinas,
                              :final areas,
                            ) =>
                              '$departamento${disciplinas.isEmpty ? '' : ' • Leciona ${disciplinas.join(', ')}'}'
                                  '${areas.isEmpty ? '' : '\nÁreas: ${areas.join(', ')}'}',
                            Disciplina(
                              :final id,
                              :final cargaHoraria,
                              :final departamento,
                            ) =>
                              '$id • ${cargaHoraria}h • $departamento',
                            Projeto(:final descricao, :final contato) =>
                              contato == null
                                  ? descricao
                                  : '$descricao\n$contato',
                            _ => '',
                          }),
                        ],
                      ),
                    ),
                    _ResumoNotas(alvo),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (sessao.pode(Area.avaliacoes, Acao.publicar))
              _FormAvaliacao(alvo: alvo)
            else
              const AvisoStatus(
                icone: Icons.lock_outline,
                cor: Colors.grey,
                texto: 'Apenas estudantes matriculados podem avaliar.',
              ),
            const SizedBox(height: 24),
            Text(
              'Comentários',
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            AsyncView(
              value: ref.watch(avaliacoesProvider((tipo, id))),
              data: (lista) {
                final comComentario = lista
                    .where((a) => a.comentario.isNotEmpty)
                    .toList();
                if (comComentario.isEmpty) {
                  return const EstadoVazio(
                    icone: Icons.chat_bubble_outline,
                    titulo: 'Nenhum comentário ainda',
                  );
                }
                return Column(
                  children: [
                    for (final a in comComentario)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 14,
                                      child: Icon(
                                        Icons.person_off_outlined,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Estudante anônimo',
                                      style: t.textTheme.labelLarge,
                                    ),
                                    const SizedBox(width: 8),
                                    Estrelas(
                                      nota: a.nota.toDouble(),
                                      tamanho: 16,
                                    ),
                                    const Spacer(),
                                    Text(
                                      dataFormatada(a.createdAt),
                                      style: t.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  a.comentario,
                                  style: t.textTheme.bodyMedium?.copyWith(
                                    height: 1.4,
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
          ],
        );
      },
    );
  }
}

class _ResumoNotas extends StatelessWidget {
  const _ResumoNotas(this.alvo);

  final Avaliavel alvo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final total = alvo.totalAvaliacoes;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          children: [
            Text(
              total == 0 ? '–' : alvo.mediaAvaliacao.toStringAsFixed(1),
              style: t.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            Estrelas(nota: alvo.mediaAvaliacao, tamanho: 18),
            const SizedBox(height: 4),
            Text('$total avaliações', style: t.textTheme.bodySmall),
          ],
        ),
        const SizedBox(width: 24),
        SizedBox(
          width: 180,
          child: Column(
            children: [
              for (var n = 5; n >= 1; n--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        child: Text('$n', style: t.textTheme.bodySmall),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: total == 0
                                ? 0
                                : (alvo.distribuicao[n] ?? 0) / total,
                            minHeight: 8,
                            color: const Color(0xFFF2A900),
                            backgroundColor:
                                t.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${alvo.distribuicao[n] ?? 0}',
                          style: t.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormAvaliacao extends ConsumerStatefulWidget {
  const _FormAvaliacao({required this.alvo});

  final Avaliavel alvo;

  @override
  ConsumerState<_FormAvaliacao> createState() => _FormAvaliacaoState();
}

class _FormAvaliacaoState extends ConsumerState<_FormAvaliacao> {
  int _nota = 0;
  final _comentario = TextEditingController();
  bool _enviando = false;
  bool _editando = false;

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      final r = await ref
          .read(comunidadeRepositoryProvider)
          .avaliar(
            tipoAlvo: widget.alvo.tipoAlvo,
            alvoId: widget.alvo.id,
            nota: _nota,
            comentario: _comentario.text.trim(),
            editar: _editando,
          );
      if (!mounted) return;
      switch (r) {
        case AvaliacaoExistente(:final nota, :final comentario):
          // RF05, fluxo alternativo 1: oferece a edição da avaliação anterior.
          final editar = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Você já avaliou este item'),
              content: Text(
                'Sua avaliação anterior: $nota estrela(s)${comentario.isEmpty ? '' : '\n\n"$comentario"'}\n\n'
                'Deseja substituí-la pela nova avaliação?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Manter a anterior'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Editar avaliação'),
                ),
              ],
            ),
          );
          if (editar == true) {
            _editando = true;
            await _enviar();
            return;
          }
        case AvaliacaoRegistrada(:final editada):
          mostrarSucesso(
            context,
            editada
                ? 'Avaliação atualizada anonimamente.'
                : 'Obrigado! Sua avaliação anônima foi registrada.',
          );
          setState(() {
            _nota = 0;
            _comentario.clear();
            _editando = false;
          });
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sua avaliação',
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Estrelas(
              nota: _nota.toDouble(),
              tamanho: 36,
              onChanged: (n) => setState(() => _nota = n),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comentario,
              maxLength: 1000,
              minLines: 2,
              maxLines: 6,
              buildCounter: contadorCaracteres,
              decoration: const InputDecoration(
                hintText: 'Comentário opcional: didática, avaliações, carga de trabalho...',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: t.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Sua identidade não é registrada.',
                    style: t.textTheme.bodySmall,
                  ),
                ),
                FilledButton(
                  onPressed: _enviando || _nota == 0 ? null : _enviar,
                  child: _enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enviar avaliação'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
