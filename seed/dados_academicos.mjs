// Dados acadêmicos reais da UFJF, montados a partir do levantamento em seed/pesquisa/*.json
// (cada arquivo traz as fontes oficiais consultadas, as lacunas e a data de acesso).
import { readFileSync } from 'node:fs';

const ler = (nome) => JSON.parse(readFileSync(new URL(`./pesquisa/${nome}.json`, import.meta.url), 'utf8')).dados;
const gradeCC = ler('grade_cc');
const gradeSI = ler('grade_si');
const gradeEC = ler('grade_ec');
const catalogo = ler('cursos_ufjf');
const docentes = ler('docentes');
const pesquisaProjetos = ler('projetos');

// Mesma regra de functions/src/historico_parser.ts (nomes do SIGA vêm em caixa alta).
const MINUSCULAS = new Set(['de', 'da', 'do', 'das', 'dos', 'e', 'em', 'a', 'o', 'à', 'às', 'ao', 'aos', 'para', 'com', 'na', 'no', 'nas', 'nos']);
const ROMANOS = /^(i{1,3}|iv|v|vi{0,3}|ix|x)$/i;
export function tituloCase(nome) {
  return nome.toLowerCase().split(/\s+/).map((p, i) => {
    if (ROMANOS.test(p)) return p.toUpperCase();
    if (i > 0 && MINUSCULAS.has(p)) return p;
    return p.charAt(0).toUpperCase() + p.slice(1);
  }).join(' ');
}
const slug = (t) => t.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

// ---------- cursos com grade completa ----------
// id interno → código SIGA. 65AC (ingresso pelo BI em Ciências Exatas) segue a grade do 65C.
const SIGLA_PARA_ID = { '65C': 'cc', '35A': 'ccn', '76A': 'si', '65B': 'ec' };

const infoCC = Object.fromEntries(gradeCC.cursos.map((c) => [c.codigoSiga, c]));
export const cursos = [
  {
    id: 'cc', nome: 'Ciência da Computação', codigo: '65C', codigosAlternativos: ['65AC'], turno: 'Integral',
    totalPeriodos: 8, cargaHoraria: 3270, grau: 'Bacharelado', campus: 'Juiz de Fora', unidade: 'ICE',
    site: infoCC['65C'].site, descricao: infoCC['65C'].descricao, temGrade: true,
  },
  {
    id: 'ccn', nome: 'Ciência da Computação', codigo: '35A', codigosAlternativos: [], turno: 'Noturno',
    totalPeriodos: 9, cargaHoraria: 3270, grau: 'Bacharelado', campus: 'Juiz de Fora', unidade: 'ICE',
    site: infoCC['35A'].site, descricao: infoCC['35A'].descricao, temGrade: true,
  },
  {
    id: 'si', nome: 'Sistemas de Informação', codigo: '76A', codigosAlternativos: [], turno: 'Noturno',
    totalPeriodos: 8, cargaHoraria: 3000, grau: 'Bacharelado', campus: 'Juiz de Fora', unidade: 'ICE',
    site: gradeSI.cursos[0].site, descricao: gradeSI.cursos[0].descricao, temGrade: true,
  },
  {
    id: 'ec', nome: 'Engenharia Computacional', codigo: '65B', codigosAlternativos: [], turno: 'Integral',
    totalPeriodos: 10, cargaHoraria: 3740, grau: 'Bacharelado', campus: 'Juiz de Fora', unidade: 'ICE',
    site: gradeEC.cursos[0].site, descricao: gradeEC.cursos[0].descricao, temGrade: true,
  },
];

// Demais cursos presenciais (catálogo para busca e cadastro; sem grade publicada no app).
const JA_COM_GRADE = /^(Ciência da Computação|Sistemas de Informação|Engenharia Computacional)$/;
const TURNO = { integral: 'Integral', noturno: 'Noturno', diurno: 'Diurno', vespertino: 'Vespertino', matutino: 'Matutino' };
const idsCatalogo = new Set();
for (const c of catalogo.cursos) {
  if (c.campus === 'Juiz de Fora' && JA_COM_GRADE.test(c.nome)) continue;
  const gv = c.campus === 'Governador Valadares';
  let id = slug(`${c.nome}-${c.grau}-${c.turno}${gv ? '-gv' : ''}`);
  while (idsCatalogo.has(id)) id += '-2';
  idsCatalogo.add(id);
  cursos.push({
    id, nome: c.nome, codigo: c.codigoSiga ?? '', codigosAlternativos: [], turno: TURNO[c.turno] ?? c.turno ?? '',
    totalPeriodos: c.duracaoPeriodos ?? 8, cargaHoraria: null, grau: tituloCase(c.grau ?? ''), campus: c.campus,
    unidade: c.unidade ?? null, site: c.site ?? c.paginaUfjf ?? null, descricao: null, temGrade: false,
  });
}

// ---------- disciplinas ----------
// Formato para o seed: { codigo, nome, cargaHoraria, departamento, preRequisitos, preRequisitosPorCurso,
//                        periodoPorCurso, eletivaEm, ementa }
const porCodigo = new Map();
function incorporar(lista, siglas) {
  for (const d of lista) {
    const e = porCodigo.get(d.codigo) ?? {
      codigo: d.codigo, nome: tituloCase(d.nomeOficialSiga ?? d.nome), cargaHoraria: d.cargaHoraria ?? 60,
      departamento: d.departamento ?? d.codigo.slice(0, 3), preRequisitosPorCurso: {}, periodoPorCurso: {}, eletivaEm: [],
      ementa: null,
    };
    e.ementa ??= d.ementa ?? null;
    for (const sigla of siglas) {
      const id = SIGLA_PARA_ID[sigla];
      const periodo = d.periodo?.[sigla];
      const eletiva = (d.eletivaEm ?? []).includes(sigla) || (siglas.length === 1 && !d.obrigatoria && !periodo);
      if (!periodo && !eletiva) continue;
      if (periodo) e.periodoPorCurso[id] = periodo;
      else if (!e.eletivaEm.includes(id)) e.eletivaEm.push(id);
      e.preRequisitosPorCurso[id] = d.preRequisitosPorCurso?.[sigla] ?? d.preRequisitos ?? [];
    }
    porCodigo.set(d.codigo, e);
  }
}
incorporar(gradeCC.disciplinas, ['65C', '35A']);
incorporar(gradeSI.disciplinas, ['76A']);
incorporar(gradeEC.disciplinas, ['65B']);

// Pré-requisitos que apontam para disciplinas fora das três grades: usa o nome do catálogo dos
// departamentos quando existe; senão descarta o vínculo (registrado em `prerequisitosDescartados`).
export const prerequisitosDescartados = [];
for (const e of porCodigo.values()) {
  for (const [curso, pres] of Object.entries(e.preRequisitosPorCurso)) {
    e.preRequisitosPorCurso[curso] = pres.filter((p) => {
      if (porCodigo.has(p)) return true;
      const nome = docentes.catalogoDisciplinas[p];
      if (nome) {
        porCodigo.set(p, { codigo: p, nome: tituloCase(nome), cargaHoraria: 60, departamento: p.slice(0, 3),
          preRequisitosPorCurso: {}, periodoPorCurso: {}, eletivaEm: [], ementa: null });
        return true;
      }
      prerequisitosDescartados.push(`${e.codigo}→${p}`);
      return false;
    });
  }
  // Lista única (união) para telas fora do contexto de um curso.
  e.preRequisitos = [...new Set(Object.values(e.preRequisitosPorCurso).flat())];
}
// Disciplinas citadas no histórico real do SIGA usado na calibração (fora das grades acima).
for (const [codigo, nome, ch, depto] of [
  ['MAT147', 'Análise I', 60, 'MAT'], ['MAT152', 'Análise II', 60, 'MAT'], ['MAT119', 'Estruturas Algébricas', 60, 'MAT'],
  ['FIS111', 'Laboratório de Eletricidade e Eletrônica', 30, 'FIS'], ['DCC197', 'Visão Computacional', 60, 'DCC'],
]) {
  if (!porCodigo.has(codigo)) {
    porCodigo.set(codigo, { codigo, nome, cargaHoraria: ch, departamento: depto, preRequisitos: [], preRequisitosPorCurso: {},
      periodoPorCurso: {}, eletivaEm: [], ementa: null });
  }
}
export const disciplinas = [...porCodigo.values()].map((e) => ({ preRequisitos: [], ...e }));

// ---------- departamentos e docentes ----------
export const departamentos = docentes.departamentos.map((d) => ({
  id: d.sigla, nome: d.nome, unidade: d.unidade, site: d.site ?? null, chefe: d.chefe ?? null, viceChefe: d.viceChefe ?? null,
}));
const nomeDepartamento = Object.fromEntries(departamentos.map((d) => [d.id, d.nome]));

// Professores reais (nome e vínculo públicos). Sem avaliações semeadas: só a comunidade avalia.
const idsProfessores = new Set();
export const professores = docentes.docentes.map((p) => {
  let id = slug(p.nome);
  while (idsProfessores.has(id)) id += '-2';
  idsProfessores.add(id);
  return {
    id,
    nome: p.nome,
    departamento: nomeDepartamento[p.departamento] ?? p.departamento,
    disciplinas: (p.disciplinasLecionadas ?? []).filter((c) => porCodigo.has(c)),
    areas: p.areasAtuacao ?? [],
  };
});

// ---------- projetos ----------
export const projetos = pesquisaProjetos.projetos.map((p) => ({
  id: p.id,
  nome: p.sigla && !p.nome.includes(p.sigla) ? `${p.nome} (${p.sigla})` : p.nome,
  categoria: p.categoria,
  coordenador: p.coordenacao ?? p.unidade ?? '',
  descricao: p.descricao,
  contato: p.site ?? p.instagram ?? null,
  comoParticipar: p.comoParticipar ?? null,
}));

// ---------- históricos de demonstração (fictícios, sobre a grade real do 65C) ----------
const nome = (codigo) => porCodigo.get(codigo).nome;
const daGrade = (curso, periodo) => disciplinas
  .filter((d) => d.periodoPorCurso[curso] === periodo)
  .map((d) => d.codigo)
  .sort();

// Bruno: veterano de Ciência da Computação integral, no 6º período (ingressou em 2024/1).
// Reprovou Cálculo I uma vez e refez no período seguinte.
const SEMESTRES_BRUNO = ['2024/1', '2024/3', '2025/1', '2025/3', '2026/1', '2026/3'];
const NOTAS = [88, 76, 81, 74, 90, 79, 68, 65, 92, 95, 77, 70, 84, 87, 91, 73, 94, 80, 83, 78, 72, 85, 88, 96, 86, 71, 89, 82, 75, 93];
let n = 0;
const disciplinasBruno = [];
for (let periodo = 1; periodo <= 6; periodo++) {
  const semestre = SEMESTRES_BRUNO[periodo - 1];
  for (const codigo of daGrade('cc', periodo)) {
    if (periodo === 6) {
      disciplinasBruno.push([codigo, nome(codigo), 'cursando', null, semestre]);
    } else if (codigo === 'MAT154') {
      disciplinasBruno.push([codigo, nome(codigo), 'reprovado', 42, semestre]);
      disciplinasBruno.push([codigo, nome(codigo), 'aprovado', 71, SEMESTRES_BRUNO[periodo]]);
    } else {
      const zeroHora = porCodigo.get(codigo).cargaHoraria === 0;
      disciplinasBruno.push([codigo, nome(codigo), 'aprovado', zeroHora ? null : NOTAS[n++ % NOTAS.length], semestre]);
    }
  }
}
export const historicoBruno = { ira: 81.6, matricula: '202465042C', curso: '65C', disciplinas: disciplinasBruno };

// Ana: caloura de Ciência da Computação integral; o PDF é gerado no layout do SIGA (RF02).
const NOTAS_ANA = { DCC199: 86.5, MAT154: 68.0, MAT155: 77.5, ICE001: 92.0, FIS122: 81.0, QUI125: 74.0, QUI126: 88.0, DC5199: 86.5 };
export const historicoAna = {
  nome: 'Ana Clara Souza Martins',
  matricula: '202665001C',
  curso: '65C - CIÊNCIA DA COMPUTAÇÃO',
  ira: 79.2,
  disciplinas: [
    ...daGrade('cc', 1).map((c) => ['2026/1', c, nome(c), porCodigo.get(c).cargaHoraria, NOTAS_ANA[c] ?? 75, 'Aprovado']),
    ...daGrade('cc', 2).map((c) => ['2026/3', c, nome(c), porCodigo.get(c).cargaHoraria, null, 'Matriculado']),
  ],
};
