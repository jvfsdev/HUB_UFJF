import 'package:flutter_test/flutter_test.dart';
import 'package:hub_ufjf/features/academico/data/grade_logic.dart';
import 'package:hub_ufjf/models/academico.dart';

Disciplina d(String id, int periodo, [List<String> pre = const []]) =>
    Disciplina(
      id: id,
      nome: id,
      cargaHoraria: 60,
      departamento: 'DCC',
      preRequisitos: pre,
      periodoPorCurso: {'cc': periodo},
    );

HistoricoEscolar historico(List<(String, SituacaoHistorico)> itens) =>
    HistoricoEscolar(
      status: 'ok',
      disciplinas: [
        for (final (c, s) in itens)
          DisciplinaHistorico(codigo: c, nome: c, situacao: s),
      ],
    );

void main() {
  final disciplinas = [
    d('ALG1', 1),
    d('CALC1', 1),
    d('ALG2', 2, ['ALG1']),
    d('ED', 3, ['ALG2']),
    d('GRAFOS', 4, ['ED', 'CALC1']),
  ];

  test('sem histórico, todas as disciplinas ficam sem estado', () {
    final g = Grade('cc', disciplinas);
    expect(g.temHistorico, isFalse);
    expect(g.estado('ED'), EstadoDisciplina.semHistorico);
    expect(g.porPeriodo.keys, [1, 2, 3, 4]);
  });

  test('classifica cursadas, cursando, disponíveis e bloqueadas', () {
    final g = Grade(
      'cc',
      disciplinas,
      historico: historico([
        ('ALG1', SituacaoHistorico.aprovado),
        ('CALC1', SituacaoHistorico.cursando),
      ]),
    );
    expect(g.estado('ALG1'), EstadoDisciplina.cursada);
    expect(g.estado('CALC1'), EstadoDisciplina.cursando);
    expect(g.estado('ALG2'), EstadoDisciplina.disponivel);
    expect(g.estado('ED'), EstadoDisciplina.bloqueada);
    expect(g.faltando('GRAFOS'), ['ED', 'CALC1']);
    expect(g.progresso, closeTo(0.2, 0.001));
  });

  test('reprovação não conta como cursada', () {
    final g = Grade(
      'cc',
      disciplinas,
      historico: historico([('ALG1', SituacaoHistorico.reprovado)]),
    );
    expect(g.estado('ALG1'), EstadoDisciplina.disponivel);
    expect(g.estado('ALG2'), EstadoDisciplina.bloqueada);
  });

  test('cadeias transitivas de pré-requisitos e dependentes', () {
    final g = Grade('cc', disciplinas);
    expect(g.preRequisitosTransitivos('GRAFOS'), {
      'ED',
      'ALG2',
      'ALG1',
      'CALC1',
    });
    expect(g.dependentesTransitivos('ALG1'), {'ALG2', 'ED', 'GRAFOS'});
    expect(g.dependentesDiretos('ALG1'), {'ALG2'});
  });

  test('usa os pré-requisitos do curso selecionado (integral × noturno)', () {
    // DCC025 exige Algoritmos II no integral (65C) e só Algoritmos no noturno (35A).
    const poo = Disciplina(
      id: 'DCC025',
      nome: 'Orientação a Objetos',
      cargaHoraria: 60,
      departamento: 'DCC',
      preRequisitos: ['DCC200', 'DCC199'],
      periodoPorCurso: {'cc': 3, 'ccn': 3},
      preRequisitosPorCurso: {
        'cc': ['DCC200'],
        'ccn': ['DCC199'],
      },
    );
    final h = historico([('DCC199', SituacaoHistorico.aprovado)]);
    expect(
      Grade('cc', [poo], historico: h).estado('DCC025'),
      EstadoDisciplina.bloqueada,
    );
    expect(
      Grade('ccn', [poo], historico: h).estado('DCC025'),
      EstadoDisciplina.disponivel,
    );
  });

  test('curso do histórico casa também pelo código alternativo (65AC)', () {
    const cc = Curso(
      id: 'cc',
      nome: 'Ciência da Computação',
      codigo: '65C',
      turno: 'Integral',
      totalPeriodos: 8,
      codigosAlternativos: ['65AC'],
    );
    expect(cc.correspondeAoCodigo('65C'), isTrue);
    expect(cc.correspondeAoCodigo('65AC'), isTrue);
    expect(cc.correspondeAoCodigo('65A'), isFalse);
    expect(cc.rotulo, 'Ciência da Computação · integral');
  });

  test('sugere cursos parecidos quando a busca não encontra (RF03 FA1)', () {
    const cursos = [
      Curso(
        id: 'cc',
        nome: 'Ciência da Computação',
        codigo: '65A',
        turno: 'Integral',
        totalPeriodos: 8,
      ),
      Curso(
        id: 'si',
        nome: 'Sistemas de Informação',
        codigo: '76A',
        turno: 'Noturno',
        totalPeriodos: 8,
      ),
      Curso(
        id: 'ec',
        nome: 'Engenharia Computacional',
        codigo: '65B',
        turno: 'Integral',
        totalPeriodos: 10,
      ),
    ];
    final sugestoes = sugerirCursos('computaçao', cursos);
    expect(sugestoes.map((c) => c.id), containsAll(['cc', 'ec']));
    expect(sugerirCursos('', cursos), isEmpty);
  });
}
