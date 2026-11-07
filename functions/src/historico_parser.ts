/**
 * RF02 — extração das disciplinas a partir do texto do histórico escolar emitido pelo SIGA/UFJF.
 *
 * Layout do SIGA (uma disciplina por registro; nomes longos podem quebrar em várias linhas):
 *   ANO SEM [CÓDIGO] NOME NOTA RESULTADO CH
 *   2024 1 [DCC199] ALGORITMOS 97 Aprovado 90
 *   2024 1 [DC5199] ALGORITMOS - PRÁTICA 97 Aprovado 0
 *   2024 3 [MAT147] ANÁLISE I 12 Rep Nota 60
 *   2026 3 [DCC070] ORGANIZAÇÃO DE COMPUTADORES Matriculado 60
 */

export type Situacao = "aprovado" | "reprovado" | "cursando" | "dispensado" | "trancado";

export interface DisciplinaHistorico {
  codigo: string;
  nome: string;
  situacao: Situacao;
  nota: number | null;
  periodo: string | null;
}

export interface HistoricoExtraido {
  disciplinas: DisciplinaHistorico[];
  ira: number | null;
  matricula: string | null;
  /** Código do curso no SIGA (ex.: "65B"), usado para abrir a grade certa. */
  cursoCodigo: string | null;
}

export class HistoricoInvalidoError extends Error {}

// Códigos do SIGA: DCC199, DC5199 (prática), EADDCC044 (EaD), MAT029E (turma especial).
const INICIO_REGISTRO = /^(\d{4})\s+(\d)\s+\[([A-Z]{2,6}\d{3,4}[A-Z]?)\]\s*/;

// Resultados possíveis no SIGA, do mais específico para o mais genérico.
const RESULTADOS: [RegExp, Situacao][] = [
  [/\bRep(?:rovado)?\s*(?:por\s*)?(?:Nota|Freq(?:u[eê]ncia)?|Nota\/Freq)\b|\bReprovad[oa]\b/i, "reprovado"],
  [/\bAprovad[oa]\b/i, "aprovado"],
  [/\bMatriculad[oa]\b|\bCursando\b|\bEm curso\b/i, "cursando"],
  [/\bDispensad[oa]\b|\bAproveitamento\b|\bIsent[oa]\b|\bEquival[eê]ncia\b/i, "dispensado"],
  [/\bTrancad[oa]\b|\bCancelad[oa]\b/i, "trancado"],
];

/** Remove sufixos de turma especial (ex.: MAT029E → MAT029) para casar com a grade. */
const codigoBase = (codigo: string) => codigo.replace(/(\d)[A-Z]$/, "$1");

function tituloCase(nome: string): string {
  const minusculas = new Set(["de", "da", "do", "das", "dos", "e", "em", "a", "o", "à", "às", "ao", "aos", "para", "com", "na", "no", "nas", "nos"]);
  const romanos = /^(i{1,3}|iv|v|vi{0,3}|ix|x)$/i;
  return nome
    .toLowerCase()
    .split(/\s+/)
    .map((p, i) => {
      if (romanos.test(p)) return p.toUpperCase();
      if (i > 0 && minusculas.has(p)) return p;
      return p.charAt(0).toUpperCase() + p.slice(1);
    })
    .join(" ");
}

/** Junta as linhas de cada registro (nomes quebrados) e descarta cabeçalhos/rodapés de página. */
function registros(texto: string): string[] {
  const lista: string[] = [];
  let atual: string | null = null;
  for (const bruta of texto.split(/\r?\n/)) {
    const linha = bruta.replace(/\s+/g, " ").trim();
    if (!linha) continue;
    if (INICIO_REGISTRO.test(linha)) {
      if (atual) lista.push(atual);
      atual = linha;
    } else if (atual) {
      // Fim do registro ao chegar no rodapé/cabeçalho da página seguinte.
      if (/^(Pág\.|--|MATRÍCULA:|CARGA HOR|Crit[eé]rios)/i.test(linha)) {
        lista.push(atual);
        atual = null;
      } else {
        atual += ` ${linha}`;
      }
    }
  }
  if (atual) lista.push(atual);
  return lista;
}

function parseRegistro(registro: string): DisciplinaHistorico | null {
  const inicio = registro.match(INICIO_REGISTRO);
  if (!inicio) return null;
  const [prefixo, ano, semestre, codigo] = inicio;
  const resto = registro.slice(prefixo.length);

  const resultado = RESULTADOS.map(([re, situacao]) => ({ m: resto.match(re), situacao })).find((r) => r.m);
  if (!resultado?.m) return null;

  const antes = resto.slice(0, resultado.m.index).trim();
  // A nota (0–100) é o último número antes do resultado; disciplinas em curso não têm nota.
  const notaMatch = antes.match(/\s(\d{1,3}(?:[.,]\d{1,2})?)$/);
  const nota = notaMatch ? Number(notaMatch[1].replace(",", ".")) : null;
  const nome = (notaMatch ? antes.slice(0, notaMatch.index) : antes).trim();

  return {
    codigo: codigoBase(codigo),
    nome: tituloCase(nome || codigo),
    situacao: resultado.situacao,
    nota: resultado.situacao === "cursando" || nota === null || nota > 100 ? null : nota,
    periodo: `${ano}/${semestre}`,
  };
}

export function parseHistorico(texto: string): HistoricoExtraido {
  const disciplinas = new Map<string, DisciplinaHistorico>();
  for (const r of registros(texto)) {
    const d = parseRegistro(r);
    // Registros vêm em ordem cronológica: uma aprovação posterior substitui a reprovação.
    if (d) disciplinas.set(d.codigo, d);
  }

  if (disciplinas.size === 0) {
    throw new HistoricoInvalidoError(
      "Não encontramos disciplinas neste arquivo. Verifique se é o histórico escolar oficial emitido pelo SIGA.",
    );
  }

  const ira = texto.match(/(?:ÍNDICE DE RENDIMENTO ACADÊMICO|\bIRA\b)\s*:?\s*(\d{1,3}(?:[.,]\d+)?)/i)?.[1];
  const matricula = texto.match(/MATR[ÍI]CULA\s*:?\s*(\d{9}[A-Z]?)/i)?.[1] ?? null;
  const cursoCodigo = texto.match(/\bCURSO\s*:\s*([0-9]{2}[A-Z]{1,2})\b/i)?.[1] ?? null;

  return {
    disciplinas: [...disciplinas.values()],
    ira: ira ? Number(ira.replace(",", ".")) : null,
    matricula,
    cursoCodigo,
  };
}
