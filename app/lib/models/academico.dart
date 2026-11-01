import 'package:cloud_firestore/cloud_firestore.dart';

class Curso {
  const Curso({
    required this.id,
    required this.nome,
    required this.codigo,
    required this.turno,
    required this.totalPeriodos,
    this.descricao,
    this.codigosAlternativos = const [],
    this.temGrade = true,
    this.grau,
    this.campus,
    this.unidade,
    this.site,
  });

  final String id;
  final String nome;

  /// Código do curso no SIGA (ex.: "65C"); vazio quando não é público.
  final String codigo;
  final String turno;
  final int totalPeriodos;
  final String? descricao;

  /// Outros códigos de ingresso com a mesma grade (ex.: 65AC, pelo BI em Ciências Exatas).
  final List<String> codigosAlternativos;

  /// Se a grade curricular completa está cadastrada (RF03).
  final bool temGrade;
  final String? grau;
  final String? campus;
  final String? unidade;
  final String? site;

  /// Nome para listas, distinguindo turnos e o campus de Governador Valadares.
  String get rotulo => [
    nome,
    if (turno.isNotEmpty) turno.toLowerCase(),
    if (campus == 'Governador Valadares') 'GV',
  ].join(' · ');

  bool correspondeAoCodigo(String? c) =>
      c != null &&
      c.isNotEmpty &&
      (codigo == c || codigosAlternativos.contains(c));

  factory Curso.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Curso(
      id: doc.id,
      nome: d['nome'] as String? ?? '',
      codigo: d['codigo'] as String? ?? '',
      turno: d['turno'] as String? ?? '',
      totalPeriodos: (d['totalPeriodos'] as num?)?.toInt() ?? 8,
      descricao: d['descricao'] as String?,
      codigosAlternativos: List<String>.from(
        d['codigosAlternativos'] as List? ?? const [],
      ),
      temGrade: d['temGrade'] as bool? ?? true,
      grau: d['grau'] as String?,
      campus: d['campus'] as String?,
      unidade: d['unidade'] as String?,
      site: d['site'] as String?,
    );
  }
}

/// Alvo de avaliação anônima (RF05): disciplina, professor ou projeto.
abstract class Avaliavel {
  String get id;
  String get nome;
  String get tipoAlvo;
  double get mediaAvaliacao;
  int get totalAvaliacoes;
  Map<int, int> get distribuicao;
}

Map<int, int> _distribuicao(dynamic m) => {
  for (var n = 1; n <= 5; n++) n: ((m as Map?)?['$n'] as num?)?.toInt() ?? 0,
};

/// Disciplina com autoassociação de pré-requisitos (RF03).
class Disciplina implements Avaliavel {
  const Disciplina({
    required this.id,
    required this.nome,
    required this.cargaHoraria,
    required this.departamento,
    required this.preRequisitos,
    required this.periodoPorCurso,
    this.preRequisitosPorCurso = const {},
    this.eletivaEm = const [],
    this.ementa,
    this.mediaAvaliacao = 0,
    this.totalAvaliacoes = 0,
    this.distribuicao = const {},
  });

  @override
  final String id;
  @override
  final String nome;
  final int cargaHoraria;
  final String departamento;

  /// União dos pré-requisitos em todos os cursos (para telas fora de uma grade).
  final List<String> preRequisitos;
  final Map<String, int> periodoPorCurso;

  /// Pré-requisitos de cada curso: a mesma disciplina pode exigir coisas diferentes
  /// no integral e no noturno (ex.: DCC025).
  final Map<String, List<String>> preRequisitosPorCurso;
  final List<String> eletivaEm;
  final String? ementa;
  @override
  final double mediaAvaliacao;
  @override
  final int totalAvaliacoes;
  @override
  final Map<int, int> distribuicao;

  String get codigo => id;

  List<String> preRequisitosNo(String cursoId) =>
      preRequisitosPorCurso[cursoId] ?? preRequisitos;

  @override
  String get tipoAlvo => 'disciplina';

  factory Disciplina.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Disciplina(
      id: doc.id,
      nome: d['nome'] as String? ?? doc.id,
      cargaHoraria: (d['cargaHoraria'] as num?)?.toInt() ?? 60,
      departamento: d['departamento'] as String? ?? '',
      preRequisitos: List<String>.from(d['preRequisitos'] as List? ?? const []),
      periodoPorCurso: {
        for (final e in ((d['periodoPorCurso'] as Map?) ?? const {}).entries)
          e.key as String: (e.value as num).toInt(),
      },
      preRequisitosPorCurso: {
        for (final e
            in ((d['preRequisitosPorCurso'] as Map?) ?? const {}).entries)
          e.key as String: List<String>.from(e.value as List),
      },
      eletivaEm: List<String>.from(d['eletivaEm'] as List? ?? const []),
      ementa: d['ementa'] as String?,
      mediaAvaliacao: (d['mediaAvaliacao'] as num?)?.toDouble() ?? 0,
      totalAvaliacoes: (d['totalAvaliacoes'] as num?)?.toInt() ?? 0,
      distribuicao: _distribuicao(d['distribuicao']),
    );
  }
}

class Professor implements Avaliavel {
  const Professor({
    required this.id,
    required this.nome,
    required this.departamento,
    required this.disciplinas,
    this.areas = const [],
    this.mediaAvaliacao = 0,
    this.totalAvaliacoes = 0,
    this.distribuicao = const {},
  });

  @override
  final String id;
  @override
  final String nome;
  final String departamento;
  final List<String> disciplinas;

  /// Áreas de atuação publicadas pelo departamento ou grupo de pesquisa.
  final List<String> areas;
  @override
  final double mediaAvaliacao;
  @override
  final int totalAvaliacoes;
  @override
  final Map<int, int> distribuicao;

  @override
  String get tipoAlvo => 'professor';

  factory Professor.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Professor(
      id: doc.id,
      nome: d['nome'] as String? ?? '',
      departamento: d['departamento'] as String? ?? '',
      disciplinas: List<String>.from(d['disciplinas'] as List? ?? const []),
      areas: List<String>.from(d['areas'] as List? ?? const []),
      mediaAvaliacao: (d['mediaAvaliacao'] as num?)?.toDouble() ?? 0,
      totalAvaliacoes: (d['totalAvaliacoes'] as num?)?.toInt() ?? 0,
      distribuicao: _distribuicao(d['distribuicao']),
    );
  }
}

class Projeto implements Avaliavel {
  const Projeto({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.categoria,
    required this.coordenador,
    this.contato,
    this.mediaAvaliacao = 0,
    this.totalAvaliacoes = 0,
    this.distribuicao = const {},
  });

  @override
  final String id;
  @override
  final String nome;
  final String descricao;
  final String categoria;
  final String coordenador;
  final String? contato;
  @override
  final double mediaAvaliacao;
  @override
  final int totalAvaliacoes;
  @override
  final Map<int, int> distribuicao;

  @override
  String get tipoAlvo => 'projeto';

  factory Projeto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Projeto(
      id: doc.id,
      nome: d['nome'] as String? ?? '',
      descricao: d['descricao'] as String? ?? '',
      categoria: d['categoria'] as String? ?? 'extensao',
      coordenador: d['coordenador'] as String? ?? '',
      contato: d['contato'] as String?,
      mediaAvaliacao: (d['mediaAvaliacao'] as num?)?.toDouble() ?? 0,
      totalAvaliacoes: (d['totalAvaliacoes'] as num?)?.toInt() ?? 0,
      distribuicao: _distribuicao(d['distribuicao']),
    );
  }
}

enum SituacaoHistorico { aprovado, reprovado, cursando, dispensado, trancado }

class DisciplinaHistorico {
  const DisciplinaHistorico({
    required this.codigo,
    required this.nome,
    required this.situacao,
    this.nota,
    this.periodo,
  });

  final String codigo;
  final String nome;
  final SituacaoHistorico situacao;
  final double? nota;
  final String? periodo;

  bool get concluida =>
      situacao == SituacaoHistorico.aprovado ||
      situacao == SituacaoHistorico.dispensado;

  factory DisciplinaHistorico.fromMap(Map<String, dynamic> m) =>
      DisciplinaHistorico(
        codigo: m['codigo'] as String,
        nome: m['nome'] as String? ?? m['codigo'] as String,
        situacao: SituacaoHistorico.values.byName(
          m['situacao'] as String? ?? 'aprovado',
        ),
        nota: (m['nota'] as num?)?.toDouble(),
        periodo: m['periodo'] as String?,
      );
}

/// Histórico escolar importado (RF02), processado pela Cloud Function.
class HistoricoEscolar {
  const HistoricoEscolar({
    required this.status,
    required this.disciplinas,
    this.ira,
    this.erro,
    this.atualizadoEm,
    this.cursoCodigo,
  });

  /// `processando`, `ok` ou `erro`.
  final String status;
  final List<DisciplinaHistorico> disciplinas;
  final double? ira;
  final String? erro;
  final DateTime? atualizadoEm;

  /// Código do curso no SIGA (ex.: "65B"), lido do PDF.
  final String? cursoCodigo;

  Set<String> get concluidas => {
    for (final d in disciplinas)
      if (d.concluida) d.codigo,
  };
  Set<String> get cursando => {
    for (final d in disciplinas)
      if (d.situacao == SituacaoHistorico.cursando) d.codigo,
  };

  factory HistoricoEscolar.fromMap(Map<String, dynamic> d) => HistoricoEscolar(
    status: d['status'] as String? ?? 'processando',
    disciplinas: [
      for (final m in (d['disciplinas'] as List? ?? const []))
        DisciplinaHistorico.fromMap(Map<String, dynamic>.from(m)),
    ],
    ira: (d['ira'] as num?)?.toDouble(),
    erro: d['erro'] as String?,
    atualizadoEm: (d['atualizadoEm'] as Timestamp?)?.toDate(),
  );
}
