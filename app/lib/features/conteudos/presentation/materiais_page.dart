import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/busca.dart';
import '../../../core/errors.dart';
import '../../../core/widgets/acoes.dart';
import '../../../core/widgets/comum.dart';
import '../../../models/academico.dart';
import '../../../models/conteudo.dart';
import '../../../models/permissoes.dart';
import '../../../models/publicacao.dart';
import '../../academico/data/academico_repository.dart';
import '../../identidade/data/identidade_repository.dart';
import '../data/conteudos_repository.dart';

/// RF08 — materiais de estudo organizados por curso e disciplina.
class MateriaisPage extends ConsumerStatefulWidget {
  const MateriaisPage({super.key, this.cursoId});

  final String? cursoId;

  @override
  ConsumerState<MateriaisPage> createState() => _MateriaisPageState();
}

class _MateriaisPageState extends ConsumerState<MateriaisPage> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider) as SessaoAtiva;
    // Só cursos com grade cadastrada têm disciplinas para organizar os materiais.
    final cursos = (ref.watch(cursosProvider).value ?? const <Curso>[])
        .where((c) => c.temGrade)
        .toList();
    final cursoId =
        [
          widget.cursoId,
          sessao.usuario.cursoId,
        ].where((id) => cursos.any((c) => c.id == id)).firstOrNull ??
        cursos.firstOrNull?.id;
    final t = Theme.of(context);

    return Pagina(
      children: [
        CabecalhoPagina(
          titulo: 'Materiais de Estudo',
          subtitulo: 'Provas antigas, listas, resumos e vídeos compartilhados pela comunidade',
          icone: Icons.menu_book_outlined,
          acao: sessao.pode(Area.materiais, Acao.publicar)
              ? FilledButton.icon(
                  onPressed: () => context.go('/materiais/novo'),
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Compartilhar material'),
                )
              : null,
        ),
        Text(
          'Adicionados recentemente',
          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: AsyncView(
            value: ref.watch(materiaisRecentesProvider),
            data: (lista) => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: lista.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(
                width: 260,
                child: CartaoMaterial(lista[i], compacto: true),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Disciplinas do curso',
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (cursos.isNotEmpty)
              DropdownButton<String>(
                value: cursoId,
                underline: const SizedBox.shrink(),
                items: [
                  for (final c in cursos)
                    DropdownMenuItem(value: c.id, child: Text(c.rotulo)),
                ],
                onChanged: (v) => context.go('/materiais?curso=$v'),
              ),
            SizedBox(
              width: 280,
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Filtrar disciplina',
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _filtro = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (cursoId != null)
          AsyncView(
            value: ref.watch(disciplinasDoCursoProvider(cursoId)),
            data: (disciplinas) {
              final porPeriodo = <int, List<Disciplina>>{};
              for (final d in disciplinas) {
                if (_filtro.isNotEmpty &&
                    !normalizar('${d.id} ${d.nome}')
                        .contains(normalizar(_filtro))) {
                  continue;
                }
                porPeriodo
                    .putIfAbsent(d.periodoPorCurso[cursoId] ?? 0, () => [])
                    .add(d);
              }
              final periodos = porPeriodo.keys.toList()..sort();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final p in periodos) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 6),
                      child: Text(
                        '$pº período',
                        style: t.textTheme.labelLarge?.copyWith(
                          color: t.colorScheme.primary,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final d
                            in porPeriodo[p]!
                              ..sort((a, b) => a.nome.compareTo(b.nome)))
                          ActionChip(
                            avatar: const Icon(Icons.folder_outlined, size: 18),
                            label: Text('${d.id} · ${d.nome}'),
                            onPressed: () =>
                                context.go('/materiais/disciplina/${d.id}'),
                          ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}

class CartaoMaterial extends StatelessWidget {
  const CartaoMaterial(this.m, {super.key, this.compacto = false});

  final MaterialEstudo m;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cor = switch (m.tipo) {
      TipoMaterial.pdf => const Color(0xFFC62828),
      TipoMaterial.video => const Color(0xFF6A1B9A),
      TipoMaterial.prova => const Color(0xFF0B3D91),
      TipoMaterial.link => const Color(0xFF00796B),
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/materiais/item/${m.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (m.youtubeId != null && !compacto)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    'https://img.youtube.com/vi/${m.youtubeId}/mqdefault.jpg',
                    width: 120,
                    height: 68,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(m.tipo.icon, color: cor, size: 40),
                  ),
                )
              else
                CircleAvatar(
                  backgroundColor: cor.withValues(alpha: 0.12),
                  child: Icon(m.tipo.icon, color: cor),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${m.disciplinaId} · ${m.tipo.label}',
                      style: t.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.download_outlined,
                          size: 14,
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                        Text(' ${m.downloads}', style: t.textTheme.bodySmall),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.visibility_outlined,
                          size: 14,
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                        Text(' ${m.views}', style: t.textTheme.bodySmall),
                      ],
                    ),
                    if (!compacto) ...[
                      const SizedBox(height: 4),
                      Text(
                        'por ${m.autorNome} · ${tempoRelativo(m.createdAt)}',
                        style: t.textTheme.bodySmall,
                      ),
                    ],
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

/// RF08 — materiais de uma disciplina, com filtro por tipo e estado vazio convidativo.
class MateriaisDisciplinaPage extends ConsumerStatefulWidget {
  const MateriaisDisciplinaPage({super.key, required this.codigo});

  final String codigo;

  @override
  ConsumerState<MateriaisDisciplinaPage> createState() =>
      _MateriaisDisciplinaPageState();
}

class _MateriaisDisciplinaPageState
    extends ConsumerState<MateriaisDisciplinaPage> {
  TipoMaterial? _tipo;

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider) as SessaoAtiva;
    final disciplina = ref
        .watch(todasDisciplinasProvider)
        .value
        ?.where((d) => d.id == widget.codigo)
        .firstOrNull;
    final podePublicar = sessao.pode(Area.materiais, Acao.publicar);
    return Pagina(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/materiais'),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Materiais'),
          ),
        ),
        CabecalhoPagina(
          titulo: disciplina?.nome ?? widget.codigo,
          subtitulo: disciplina == null
              ? null
              : '${disciplina.id} · ${disciplina.cargaHoraria}h · ${disciplina.departamento}',
          icone: Icons.folder_open_outlined,
          acao: Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    context.go('/avaliacoes/disciplina/${widget.codigo}'),
                icon: const Icon(Icons.star_outline),
                label: const Text('Avaliações'),
              ),
              if (podePublicar)
                FilledButton.icon(
                  onPressed: () =>
                      context.go('/materiais/novo?disciplina=${widget.codigo}'),
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Contribuir'),
                ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: _tipo == null,
              onSelected: (_) => setState(() => _tipo = null),
            ),
            for (final tp in TipoMaterial.values)
              ChoiceChip(
                avatar: Icon(tp.icon, size: 18),
                label: Text(tp.label),
                selected: _tipo == tp,
                onSelected: (_) => setState(() => _tipo = tp),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AsyncView(
          value: ref.watch(materiaisDisciplinaProvider(widget.codigo)),
          data: (lista) {
            final filtrada = _tipo == null
                ? lista
                : lista.where((m) => m.tipo == _tipo).toList();
            if (filtrada.isEmpty) {
              return EstadoVazio(
                icone: Icons.folder_off_outlined,
                titulo:
                    'Ainda não há materiais${_tipo != null ? ' deste tipo' : ''} para esta disciplina',
                mensagem: 'Tem uma lista resolvida, resumo ou prova antiga? Compartilhe com quem vem depois!',
                acao: podePublicar
                    ? FilledButton.icon(
                        onPressed: () => context.go(
                          '/materiais/novo?disciplina=${widget.codigo}',
                        ),
                        icon: const Icon(Icons.upload_outlined),
                        label: const Text('Contribuir com um material'),
                      )
                    : null,
              );
            }
            return Column(
              children: [
                for (final m in filtrada)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CartaoMaterial(m),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class MaterialDetalhePage extends ConsumerStatefulWidget {
  const MaterialDetalhePage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<MaterialDetalhePage> createState() =>
      _MaterialDetalhePageState();
}

class _MaterialDetalhePageState extends ConsumerState<MaterialDetalhePage> {
  bool _registrado = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final u = ref.watch(usuarioAtualProvider)!;
    return AsyncView(
      value: ref.watch(materialProvider(widget.id)),
      data: (m) {
        if (m == null || m.status == 'removido') {
          return const EstadoVazio(
            icone: Icons.block,
            titulo: 'Material indisponível',
            mensagem: 'Ele foi removido ou não existe.',
          );
        }
        if (!_registrado) {
          _registrado = true;
          ref.read(conteudosRepositoryProvider).registrarVisualizacao(m, u.uid);
        }
        final arquivo =
            m.tipo == TipoMaterial.pdf ||
            m.tipo == TipoMaterial.prova ||
            (m.tipo == TipoMaterial.video && m.youtubeId == null);
        return Pagina(
          maxWidth: 800,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    context.go('/materiais/disciplina/${m.disciplinaId}'),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(
                  m.disciplinaNome.isEmpty ? m.disciplinaId : m.disciplinaNome,
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (m.youtubeId != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  'https://img.youtube.com/vi/${m.youtubeId}/hqdefault.jpg',
                                  fit: BoxFit.cover,
                                ),
                                const Center(
                                  child: Icon(
                                    Icons.play_circle_fill,
                                    size: 72,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        TagChip(m.tipo.label, icone: m.tipo.icon),
                        const SizedBox(width: 8),
                        TagChip(m.disciplinaId, icone: Icons.class_outlined),
                        const Spacer(),
                        if (m.autorId != u.uid)
                          BotaoDenunciar(
                            alvoPath: m.path,
                            alvoTipo: 'material',
                            alvoTitulo: m.titulo,
                            compacto: true,
                          )
                        else
                          IconButton(
                            tooltip: 'Remover material',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await ref
                                  .read(conteudosRepositoryProvider)
                                  .remover(m.id);
                              if (context.mounted) {
                                context.go(
                                  '/materiais/disciplina/${m.disciplinaId}',
                                );
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      m.titulo,
                      style: t.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (m.descricao.isNotEmpty)
                      Text(
                        m.descricao,
                        style: t.textTheme.bodyLarge?.copyWith(height: 1.5),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Compartilhado por ${m.autorNome} · ${tempoRelativo(m.createdAt)}',
                      style: t.textTheme.bodySmall,
                    ),
                    Text(
                      '${m.downloads} downloads · ${m.views} visualizações'
                      '${m.tamanho != null ? ' · ${(m.tamanho! / 1048576).toStringAsFixed(1)} MB' : ''}',
                      style: t.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () {
                        ref
                            .read(conteudosRepositoryProvider)
                            .registrarDownload(m, u.uid);
                        abrirUrl(context, m.url);
                      },
                      icon: Icon(arquivo ? Icons.download : Icons.open_in_new),
                      label: Text(
                        arquivo
                            ? 'Baixar'
                            : (m.youtubeId != null
                                  ? 'Assistir no YouTube'
                                  : 'Abrir link'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// RF08 (fluxo alternativo 1) + RF11 — contribuição de material com upload ou link.
class NovoMaterialPage extends ConsumerStatefulWidget {
  const NovoMaterialPage({super.key, this.disciplinaId});

  final String? disciplinaId;

  @override
  ConsumerState<NovoMaterialPage> createState() => _NovoMaterialPageState();
}

class _NovoMaterialPageState extends ConsumerState<NovoMaterialPage> {
  final _titulo = TextEditingController();
  final _descricao = TextEditingController();
  final _link = TextEditingController();
  late String? _disciplinaId = widget.disciplinaId;
  TipoMaterial _tipo = TipoMaterial.pdf;
  List<Anexo> _arquivo = const [];
  bool _confirmaDireitos = false;
  bool _enviando = false;
  String? _erro;

  bool get _usaArquivo =>
      _tipo == TipoMaterial.pdf || _tipo == TipoMaterial.prova;

  Future<void> _salvar() async {
    if (!_confirmaDireitos) {
      setState(
        () => _erro = 'Confirme que o material pode ser compartilhado sem violar direitos autorais.',
      );
      return;
    }
    final disciplinas = ref.read(todasDisciplinasProvider).value ?? const [];
    final disciplina = disciplinas
        .where((d) => d.id == _disciplinaId)
        .firstOrNull;
    final anexo = _arquivo.firstOrNull;
    final url = _usaArquivo || (_tipo == TipoMaterial.video && anexo != null)
        ? anexo?.url ?? ''
        : _link.text.trim();
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final id = await ref
          .read(conteudosRepositoryProvider)
          .criar(
            autor: ref.read(usuarioAtualProvider)!,
            titulo: _titulo.text,
            descricao: _descricao.text,
            tipo: _tipo,
            disciplinaId: _disciplinaId ?? '',
            disciplinaNome: disciplina?.nome ?? '',
            url: url,
            tamanho: anexo?.tamanho,
          );
      if (!mounted) return;
      mostrarSucesso(
        context,
        'Material compartilhado. Obrigado por contribuir!',
      );
      context.go('/materiais/item/$id');
    } catch (e) {
      setState(() => _erro = mensagemErro(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final disciplinas =
        ref.watch(todasDisciplinasProvider).value ?? const <Disciplina>[];
    return Pagina(
      maxWidth: 720,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(
              widget.disciplinaId == null
                  ? '/materiais'
                  : '/materiais/disciplina/${widget.disciplinaId}',
            ),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Cancelar'),
          ),
        ),
        const CabecalhoPagina(
          titulo: 'Compartilhar material',
          icone: Icons.upload_outlined,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Autocomplete<Disciplina>(
                  initialValue: TextEditingValue(
                    text:
                        disciplinas
                            .where((d) => d.id == _disciplinaId)
                            .map((d) => '${d.id} · ${d.nome}')
                            .firstOrNull ??
                        '',
                  ),
                  displayStringForOption: (d) => '${d.id} · ${d.nome}',
                  optionsBuilder: (v) => disciplinas
                      .where(
                        (d) =>
                            normalizar('${d.id} ${d.nome}')
                                .contains(normalizar(v.text)),
                      )
                      .take(10),
                  onSelected: (d) => setState(() => _disciplinaId = d.id),
                  fieldViewBuilder: (context, controller, focus, onSubmit) =>
                      TextField(
                        controller: controller,
                        focusNode: focus,
                        decoration: const InputDecoration(
                          labelText: 'Disciplina',
                          prefixIcon: Icon(Icons.class_outlined),
                        ),
                      ),
                ),
                const SizedBox(height: 16),
                Text('Tipo de material', style: t.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final tp in TipoMaterial.values)
                      ChoiceChip(
                        avatar: Icon(tp.icon, size: 18),
                        label: Text(tp.label),
                        selected: _tipo == tp,
                        onSelected: (_) => setState(() {
                          _tipo = tp;
                          _arquivo = const [];
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titulo,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descricao,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                if (_usaArquivo)
                  CampoAnexos(
                    area: 'materiais',
                    anexos: _arquivo,
                    maximo: 1,
                    tiposPermitidos: const {'pdf'},
                    rotulo: 'Escolher PDF',
                    onChanged: (a) => setState(() => _arquivo = a),
                  )
                else if (_tipo == TipoMaterial.video) ...[
                  TextField(
                    controller: _link,
                    decoration: const InputDecoration(
                      labelText: 'Link do vídeo (YouTube)',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ou envie um arquivo MP4:',
                    style: t.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  CampoAnexos(
                    area: 'materiais',
                    anexos: _arquivo,
                    maximo: 1,
                    tiposPermitidos: const {'video'},
                    rotulo: 'Escolher MP4',
                    onChanged: (a) => setState(() => _arquivo = a),
                  ),
                ] else
                  TextField(
                    controller: _link,
                    decoration: const InputDecoration(
                      labelText: 'Link externo',
                      prefixIcon: Icon(Icons.link),
                      hintText: 'https://',
                    ),
                  ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _confirmaDireitos,
                  onChanged: (v) =>
                      setState(() => _confirmaDireitos = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Confirmo que este material é gratuito e pode ser compartilhado sem infringir direitos autorais.',
                  ),
                ),
                if (_erro != null)
                  Text(_erro!, style: TextStyle(color: t.colorScheme.error)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _enviando ? null : _salvar,
                  icon: const Icon(Icons.check),
                  label: const Text('Publicar material'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
