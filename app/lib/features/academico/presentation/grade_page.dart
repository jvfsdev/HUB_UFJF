import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/busca.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/comum.dart';
import '../../../models/academico.dart';
import '../../../models/usuario.dart';
import '../../identidade/data/identidade_repository.dart';
import '../data/academico_repository.dart';
import '../data/grade_logic.dart';

const _corCursada = Color(0xFF2E7D32);
const _corCursando = Color(0xFF0277BD);
const _corDisponivel = Color(0xFF0B3D91);
const _corBloqueada = Color(0xFF9E9E9E);
const _corPreRequisito = Color(0xFFEF6C00);
const _corLibera = Color(0xFF6A1B9A);

/// RF03 — grade curricular organizada por períodos com o mapa de pré-requisitos.
class GradePage extends ConsumerStatefulWidget {
  const GradePage({super.key, this.cursoId});

  final String? cursoId;

  @override
  ConsumerState<GradePage> createState() => _GradePageState();
}

class _GradePageState extends ConsumerState<GradePage> {
  String? _selecionada;
  String? _naoEncontrado;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final usuario = ref.watch(usuarioAtualProvider)!;
    final cursos = ref.watch(cursosProvider).value ?? const <Curso>[];
    final historico = usuario.perfil == Perfil.estudante
        ? ref.watch(meuHistoricoProvider).value
        : null;
    // Sem curso na URL, abre o curso do histórico importado (RF02 → RF03) ou o do perfil.
    final cursoDoHistorico = cursos
        .where((c) => c.correspondeAoCodigo(historico?.cursoCodigo))
        .firstOrNull
        ?.id;
    final cursoId =
        widget.cursoId ??
        cursoDoHistorico ??
        usuario.cursoId ??
        cursos.where((c) => c.temGrade).firstOrNull?.id;
    final curso = cursos.where((c) => c.id == cursoId).firstOrNull;

    return Pagina(
      maxWidth: 1400,
      children: [
        CabecalhoPagina(
          titulo: 'Grade Curricular',
          subtitulo: curso == null
              ? null
              : curso.temGrade
              ? '${curso.nome} · ${curso.turno} · ${curso.totalPeriodos} períodos'
              : curso.rotulo,
          icone: Icons.account_tree_outlined,
          acao: usuario.perfil == Perfil.estudante
              ? OutlinedButton.icon(
                  onPressed: () => context.go('/grade/historico'),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(
                    historico?.status == 'ok'
                        ? 'Atualizar histórico'
                        : 'Importar histórico',
                  ),
                )
              : null,
        ),
        _BuscaCurso(
          cursos: cursos,
          onSelecionar: (c) {
            setState(() {
              _naoEncontrado = null;
              _selecionada = null;
            });
            context.go('/grade?curso=${c.id}');
          },
          onNaoEncontrado: (q) => setState(() => _naoEncontrado = q),
        ),
        if (_naoEncontrado != null) ...[
          const SizedBox(height: 12),
          Card(
            color: t.colorScheme.errorContainer.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Não encontramos o curso "$_naoEncontrado".',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text('Talvez você esteja procurando:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c
                          in sugerirCursos(_naoEncontrado!, cursos).ifEmpty(
                            cursos.where((c) => c.temGrade).take(3).toList(),
                          ))
                        ActionChip(
                          label: Text(c.rotulo),
                          onPressed: () {
                            setState(() => _naoEncontrado = null);
                            context.go('/grade?curso=${c.id}');
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (curso != null && !curso.temGrade)
          _GradeIndisponivel(curso: curso, cursos: cursos)
        else if (cursoId != null)
          AsyncView(
            value: ref.watch(disciplinasDoCursoProvider(cursoId)),
            data: (disciplinas) {
              final grade = Grade(cursoId, disciplinas, historico: historico);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (usuario.perfil == Perfil.estudante)
                    _ResumoProgresso(grade: grade, historico: historico),
                  const SizedBox(height: 12),
                  _Legenda(
                    temHistorico: grade.temHistorico,
                    selecionada: _selecionada != null,
                  ),
                  const SizedBox(height: 12),
                  _MapaGrade(
                    grade: grade,
                    selecionada: _selecionada,
                    onSelecionar: (c) => setState(
                      () => _selecionada = _selecionada == c ? null : c,
                    ),
                  ),
                  if (_selecionada != null &&
                      grade.disciplinas[_selecionada] != null) ...[
                    const SizedBox(height: 16),
                    _DetalheDisciplina(
                      grade: grade,
                      disciplina: grade.disciplinas[_selecionada]!,
                      onSelecionar: (c) => setState(() => _selecionada = c),
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

/// Curso do catálogo da UFJF cuja grade ainda não foi cadastrada no HUB.
class _GradeIndisponivel extends StatelessWidget {
  const _GradeIndisponivel({required this.curso, required this.cursos});

  final Curso curso;
  final List<Curso> cursos;

  @override
  Widget build(BuildContext context) {
    final comGrade = cursos.where((c) => c.temGrade).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (curso.grau != null) curso.grau!,
                if (curso.unidade != null) curso.unidade!,
                if (curso.campus != null) 'campus ${curso.campus}',
                '${curso.totalPeriodos} períodos',
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'A grade curricular deste curso ainda não está disponível no HUB-UFJF.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              curso.site == null
                  ? 'Consulte a coordenação do curso.'
                  : 'Consulte a matriz curricular no site do curso: ${curso.site}',
            ),
            const SizedBox(height: 12),
            const Text('Grades disponíveis:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in comGrade)
                  ActionChip(
                    label: Text(c.rotulo),
                    onPressed: () => context.go('/grade?curso=${c.id}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension<T> on List<T> {
  List<T> ifEmpty(List<T> alternativa) => isEmpty ? alternativa : this;
}

class _BuscaCurso extends StatelessWidget {
  const _BuscaCurso({
    required this.cursos,
    required this.onSelecionar,
    required this.onNaoEncontrado,
  });

  final List<Curso> cursos;
  final ValueChanged<Curso> onSelecionar;
  final ValueChanged<String> onNaoEncontrado;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Autocomplete<Curso>(
        displayStringForOption: (c) => c.rotulo,
        optionsBuilder: (v) => v.text.isEmpty
            ? cursos
            : cursos.where(
                (c) =>
                    normalizar('${c.nome} ${c.codigo}')
                        .contains(normalizar(v.text)),
              ),
        onSelected: onSelecionar,
        fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
          controller: controller,
          focusNode: focus,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar curso (ex.: Ciência da Computação)',
          ),
          onSubmitted: (q) {
            final achados = cursos
                .where(
                  (c) =>
                      normalizar('${c.nome} ${c.codigo}')
                          .contains(normalizar(q)),
                )
                .toList();
            if (achados.isEmpty && q.trim().isNotEmpty) {
              onNaoEncontrado(q.trim());
            } else if (achados.isNotEmpty) {
              onSelecionar(achados.first);
            }
          },
        ),
      ),
    );
  }
}

class _ResumoProgresso extends StatelessWidget {
  const _ResumoProgresso({required this.grade, required this.historico});

  final Grade grade;
  final HistoricoEscolar? historico;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (!grade.temHistorico) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.lightbulb_outline, color: ambarUfjf),
          title: Text(
            historico?.status == 'processando'
                ? 'Estamos processando seu histórico...'
                : 'Importe seu histórico para ver o que você já cursou e o que está liberado.',
          ),
          trailing: historico?.status == 'processando'
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FilledButton(
                  onPressed: () => context.go('/grade/historico'),
                  child: const Text('Importar'),
                ),
        ),
      );
    }
    Widget stat(String label, int valor, Color cor) => Column(
      children: [
        Text(
          '$valor',
          style: t.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: cor,
          ),
        ),
        Text(label, style: t.textTheme.bodySmall),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 32,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Progresso no curso', style: t.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: grade.progresso,
                      minHeight: 12,
                      color: _corCursada,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(grade.progresso * 100).toStringAsFixed(0)}% da carga horária concluída'
                    '${historico?.ira != null ? ' · IRA ${historico!.ira!.toStringAsFixed(1)}' : ''}',
                  ),
                ],
              ),
            ),
            stat(
              'cursadas',
              grade.contar(EstadoDisciplina.cursada),
              _corCursada,
            ),
            stat(
              'cursando',
              grade.contar(EstadoDisciplina.cursando),
              _corCursando,
            ),
            stat(
              'disponíveis',
              grade.contar(EstadoDisciplina.disponivel),
              _corDisponivel,
            ),
            stat(
              'bloqueadas',
              grade.contar(EstadoDisciplina.bloqueada),
              _corBloqueada,
            ),
          ],
        ),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda({required this.temHistorico, required this.selecionada});

  final bool temHistorico;
  final bool selecionada;

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String l) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(l, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        if (temHistorico) ...[
          item(_corCursada, 'Cursada'),
          item(_corCursando, 'Cursando'),
          item(_corDisponivel, 'Disponível'),
          item(_corBloqueada, 'Bloqueada'),
        ],
        item(_corPreRequisito, 'Pré-requisito da selecionada'),
        item(_corLibera, 'Liberada pela selecionada'),
        if (!selecionada)
          Text(
            'Toque em uma disciplina para ver suas dependências.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
      ],
    );
  }
}

class _MapaGrade extends StatelessWidget {
  const _MapaGrade({
    required this.grade,
    required this.selecionada,
    required this.onSelecionar,
  });

  final Grade grade;
  final String? selecionada;
  final ValueChanged<String> onSelecionar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final pre = selecionada == null
        ? const <String>{}
        : grade.preRequisitosTransitivos(selecionada!);
    final libera = selecionada == null
        ? const <String>{}
        : grade.dependentesTransitivos(selecionada!);
    final porPeriodo = grade.porPeriodo;

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entrada in porPeriodo.entries)
              Container(
                width: 190,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: t.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '${entrada.key}º período',
                        textAlign: TextAlign.center,
                        style: t.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    for (final d in entrada.value)
                      _CelulaDisciplina(
                        disciplina: d,
                        preRequisitos: grade.preRequisitos(d.id).length,
                        estado: grade.estado(d.id),
                        selecionada: selecionada == d.id,
                        destaque: pre.contains(d.id)
                            ? _corPreRequisito
                            : libera.contains(d.id)
                            ? _corLibera
                            : null,
                        esmaecida:
                            selecionada != null &&
                            selecionada != d.id &&
                            !pre.contains(d.id) &&
                            !libera.contains(d.id),
                        onTap: () => onSelecionar(d.id),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CelulaDisciplina extends StatelessWidget {
  const _CelulaDisciplina({
    required this.disciplina,
    required this.preRequisitos,
    required this.estado,
    required this.selecionada,
    required this.destaque,
    required this.esmaecida,
    required this.onTap,
  });

  final Disciplina disciplina;
  final int preRequisitos;
  final EstadoDisciplina estado;
  final bool selecionada;
  final Color? destaque;
  final bool esmaecida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final base = switch (estado) {
      EstadoDisciplina.cursada => _corCursada,
      EstadoDisciplina.cursando => _corCursando,
      EstadoDisciplina.disponivel => _corDisponivel,
      EstadoDisciplina.bloqueada => _corBloqueada,
      EstadoDisciplina.semHistorico => t.colorScheme.primary,
    };
    final preenchida =
        estado == EstadoDisciplina.cursada ||
        estado == EstadoDisciplina.cursando;
    final borda =
        destaque ??
        (selecionada ? t.colorScheme.onSurface : base.withValues(alpha: 0.5));
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: esmaecida ? 0.35 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: preenchida ? base.withValues(alpha: 0.12) : t.cardTheme.color,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: borda,
                  width: destaque != null || selecionada ? 2.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        disciplina.id,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: base,
                        ),
                      ),
                      const Spacer(),
                      if (estado == EstadoDisciplina.cursada)
                        const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: _corCursada,
                        ),
                      if (estado == EstadoDisciplina.bloqueada)
                        const Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: _corBloqueada,
                        ),
                      if (estado == EstadoDisciplina.cursando)
                        const Icon(
                          Icons.timelapse,
                          size: 14,
                          color: _corCursando,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    disciplina.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${disciplina.cargaHoraria}h'
                    '${preRequisitos == 0 ? '' : ' · $preRequisitos pré-req.'}',
                    style: t.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetalheDisciplina extends StatelessWidget {
  const _DetalheDisciplina({
    required this.grade,
    required this.disciplina,
    required this.onSelecionar,
  });

  final Grade grade;
  final Disciplina disciplina;
  final ValueChanged<String> onSelecionar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final estado = grade.estado(disciplina.id);
    final faltando = grade.faltando(disciplina.id);
    final libera = grade.dependentesDiretos(disciplina.id);
    String nome(String c) => grade.disciplinas[c]?.nome ?? c;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${disciplina.id} · ${disciplina.nome}',
                    style: t.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (grade.temHistorico)
                  TagChip(
                    switch (estado) {
                      EstadoDisciplina.cursada => 'Cursada',
                      EstadoDisciplina.cursando => 'Cursando',
                      EstadoDisciplina.disponivel => 'Disponível para cursar',
                      _ => 'Bloqueada',
                    },
                    cor: switch (estado) {
                      EstadoDisciplina.cursada => _corCursada,
                      EstadoDisciplina.cursando => _corCursando,
                      EstadoDisciplina.disponivel => _corDisponivel,
                      _ => _corBloqueada,
                    },
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${disciplina.cargaHoraria}h · ${disciplina.departamento} · ${disciplina.periodoPorCurso[grade.cursoId]}º período',
            ),
            if (disciplina.ementa != null) ...[
              const SizedBox(height: 12),
              Text(
                disciplina.ementa!,
                style: t.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 40,
              runSpacing: 16,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pré-requisitos',
                        style: t.textTheme.titleSmall?.copyWith(
                          color: _corPreRequisito,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (grade.preRequisitos(disciplina.id).isEmpty)
                        const Text('Nenhum — pode ser cursada desde o início.'),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final p in grade.preRequisitos(disciplina.id))
                            ActionChip(
                              avatar: Icon(
                                !grade.temHistorico
                                    ? Icons.link
                                    : (faltando.contains(p)
                                          ? Icons.close
                                          : Icons.check),
                                size: 16,
                                color: !grade.temHistorico
                                    ? null
                                    : (faltando.contains(p)
                                          ? Colors.red
                                          : _corCursada),
                              ),
                              label: Text('$p · ${nome(p)}'),
                              onPressed: () => onSelecionar(p),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Libera',
                        style: t.textTheme.titleSmall?.copyWith(
                          color: _corLibera,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (libera.isEmpty)
                        const Text(
                          'Não é pré-requisito de outras disciplinas do curso.',
                        ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final d in libera)
                            ActionChip(
                              label: Text('$d · ${nome(d)}'),
                              onPressed: () => onSelecionar(d),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/materiais/disciplina/${disciplina.id}'),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Materiais'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/avaliacoes/disciplina/${disciplina.id}'),
                  icon: const Icon(Icons.star_outline),
                  label: Text(
                    disciplina.totalAvaliacoes == 0
                        ? 'Avaliações'
                        : 'Avaliações (${disciplina.mediaAvaliacao.toStringAsFixed(1)}★)',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
