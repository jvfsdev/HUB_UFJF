import '../../../core/busca.dart';
import '../../../models/academico.dart';

/// Estado de uma disciplina na grade do estudante (RF03, fluxo alternativo 2).
enum EstadoDisciplina { cursada, cursando, disponivel, bloqueada, semHistorico }

/// Regras da grade curricular e do mapa de pré-requisitos, sem dependência de UI.
class Grade {
  Grade(
    this.cursoId,
    List<Disciplina> disciplinas, {
    HistoricoEscolar? historico,
  }) : disciplinas = {for (final d in disciplinas) d.id: d},
       _concluidas = historico?.status == 'ok'
           ? historico!.concluidas
           : const {},
       _cursando = historico?.status == 'ok' ? historico!.cursando : const {},
       temHistorico = historico?.status == 'ok' {
    for (final d in disciplinas) {
      for (final pre in d.preRequisitosNo(cursoId)) {
        _dependentes.putIfAbsent(pre, () => {}).add(d.id);
      }
    }
  }

  final String cursoId;
  final Map<String, Disciplina> disciplinas;
  final bool temHistorico;
  final Set<String> _concluidas;
  final Set<String> _cursando;
  final _dependentes = <String, Set<String>>{};

  int get totalPeriodos => disciplinas.values
      .map((d) => d.periodoPorCurso[cursoId] ?? 0)
      .fold(0, (a, b) => a > b ? a : b);

  /// Disciplinas por período, ordenadas por código.
  Map<int, List<Disciplina>> get porPeriodo {
    final mapa = <int, List<Disciplina>>{};
    for (final d in disciplinas.values) {
      final p = d.periodoPorCurso[cursoId];
      if (p != null && p > 0) mapa.putIfAbsent(p, () => []).add(d);
    }
    for (final lista in mapa.values) {
      lista.sort((a, b) => a.id.compareTo(b.id));
    }
    return Map.fromEntries(
      mapa.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  /// Pré-requisitos diretos da disciplina neste curso.
  List<String> preRequisitos(String codigo) =>
      disciplinas[codigo]?.preRequisitosNo(cursoId) ?? const [];

  EstadoDisciplina estado(String codigo) {
    if (!temHistorico) return EstadoDisciplina.semHistorico;
    if (_concluidas.contains(codigo)) return EstadoDisciplina.cursada;
    if (_cursando.contains(codigo)) return EstadoDisciplina.cursando;
    final pre = preRequisitos(codigo);
    return pre.every(_concluidas.contains)
        ? EstadoDisciplina.disponivel
        : EstadoDisciplina.bloqueada;
  }

  /// Pré-requisitos diretos que ainda faltam para cursar a disciplina.
  List<String> faltando(String codigo) =>
      preRequisitos(codigo).where((p) => !_concluidas.contains(p)).toList();

  /// Todos os pré-requisitos, diretos e indiretos (para destacar a cadeia "para trás").
  Set<String> preRequisitosTransitivos(String codigo) {
    final resultado = <String>{};
    void visitar(String c) {
      for (final p in preRequisitos(c)) {
        if (resultado.add(p)) visitar(p);
      }
    }

    visitar(codigo);
    return resultado;
  }

  /// Todas as disciplinas que dependem desta, direta ou indiretamente ("para frente").
  Set<String> dependentesTransitivos(String codigo) {
    final resultado = <String>{};
    void visitar(String c) {
      for (final d in _dependentes[c] ?? const <String>{}) {
        if (resultado.add(d)) visitar(d);
      }
    }

    visitar(codigo);
    return resultado;
  }

  Set<String> dependentesDiretos(String codigo) =>
      _dependentes[codigo] ?? const {};

  /// Percentual da carga horária obrigatória já concluída.
  double get progresso {
    final total = disciplinas.values.fold<int>(0, (s, d) => s + d.cargaHoraria);
    if (total == 0 || !temHistorico) return 0;
    final feita = disciplinas.values
        .where((d) => _concluidas.contains(d.id))
        .fold<int>(0, (s, d) => s + d.cargaHoraria);
    return feita / total;
  }

  int contar(EstadoDisciplina e) =>
      disciplinas.keys.where((c) => estado(c) == e).length;
}

/// RF03 (fluxo alternativo 1) — sugere cursos parecidos quando a busca não encontra nada.
List<Curso> sugerirCursos(
  String consulta,
  List<Curso> cursos, {
  int maximo = 3,
}) {
  final alvo = normalizar(consulta.trim());
  if (alvo.isEmpty) return const [];
  double similaridade(Curso c) {
    final nome = normalizar(c.nome);
    if (nome.contains(alvo) || alvo.contains(nome)) return 1;
    final palavras = alvo.split(RegExp(r'\s+')).where((p) => p.length >= 3);
    final comuns = palavras
        .where((p) => nome.contains(p.substring(0, p.length.clamp(3, 5))))
        .length;
    final bigramasA = _bigramas(alvo);
    final bigramasB = _bigramas(nome);
    final dice = bigramasA.isEmpty || bigramasB.isEmpty
        ? 0.0
        : 2 *
              bigramasA.intersection(bigramasB).length /
              (bigramasA.length + bigramasB.length);
    return dice + comuns * 0.3;
  }

  final ordenados = [...cursos]
    ..sort((a, b) => similaridade(b).compareTo(similaridade(a)));
  return ordenados.where((c) => similaridade(c) > 0.15).take(maximo).toList();
}

Set<String> _bigramas(String s) {
  final limpo = s.replaceAll(RegExp(r'\s+'), ' ');
  return {for (var i = 0; i < limpo.length - 1; i++) limpo.substring(i, i + 2)};
}
