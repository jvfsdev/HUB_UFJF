import { strict as assert } from "node:assert";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { PDFParse } from "pdf-parse";
import { HistoricoInvalidoError, parseHistorico } from "../historico_parser";

async function textoDoPdf(caminho: string): Promise<string> {
  const parser = new PDFParse({ data: readFileSync(caminho) });
  const { text } = await parser.getText();
  await parser.destroy();
  return text;
}

// Trecho fictício reproduzindo o layout do histórico do SIGA (inclusive quebra de página e de nome).
const SIGA_FICTICIO = `UNIVERSIDADE FEDERAL DE JUIZ DE FORA
HISTÓRICO ESCOLAR
MATRÍCULA: 202399999X\tNOME: FULANA DE TAL DATA NASCIMENTO: 01/01/2000
CURSO: 65C - CIÊNCIA DA COMPUTAÇÃO
ÍNDICE DE RENDIMENTO ACADÊMICO: 81,25
ANO DISCIPLINA HORAS/AULA\tRESULTADO\tSEM NOTA
2023 1 [DCC199] ALGORITMOS 97 Aprovado 90
2023 1 [DC5199] ALGORITMOS - PRÁTICA 97 Aprovado 0
2023 1 [MAT154] CÁLCULO I 12 Rep Nota 60
2023 3 [MAT154] CÁLCULO I 74 Aprovado 60
2023 3 [MAC036] REPRESENTAÇÃO GRÁFICA E MODELAGEM
GEOMÉTRICA
99 Aprovado 30
Pág. 1

-- 1 of 2 --

MATRÍCULA: 202399999X DATA NASCIMENTO: 01/01/2000\tNOME: FULANA DE TAL
2024 1 [MAT029E] EQUAÇÕES DIFERENCIAIS I 72 Aprovado 60
2024 1 [DCC059] TEORIA DOS GRAFOS 0 Rep Freq 60
2024 3 [DCC070] ORGANIZAÇÃO DE COMPUTADORES Matriculado 60
Pág. 2`;

test("extrai registros no layout do SIGA", () => {
  const h = parseHistorico(SIGA_FICTICIO);
  assert.equal(h.matricula, "202399999X");
  assert.equal(h.cursoCodigo, "65C");
  assert.equal(h.ira, 81.25);
  assert.equal(h.disciplinas.length, 7);

  const por = Object.fromEntries(h.disciplinas.map((d) => [d.codigo, d]));
  assert.deepEqual(por.DCC199, { codigo: "DCC199", nome: "Algoritmos", situacao: "aprovado", nota: 97, periodo: "2023/1" });
  assert.equal(por.DC5199.nome, "Algoritmos - Prática", "código de componente prático do SIGA");
  assert.equal(por.MAT154.situacao, "aprovado", "aprovação posterior substitui a reprovação");
  assert.equal(por.MAT154.nota, 74);
  assert.equal(por.MAC036.nome, "Representação Gráfica e Modelagem Geométrica");
  assert.equal(por.MAC036.nota, 99);
  assert.equal(por.MAT029.nome, "Equações Diferenciais I", "sufixo de turma especial é removido");
  assert.equal(por.DCC059.situacao, "reprovado");
  assert.deepEqual(por.DCC070, { codigo: "DCC070", nome: "Organização de Computadores", situacao: "cursando", nota: null, periodo: "2024/3" });
});

test("código de ingresso pelo BI em Ciências Exatas (65AC)", () => {
  assert.equal(parseHistorico(SIGA_FICTICIO.replace("65C", "65AC")).cursoCodigo, "65AC");
});

test("PDF de demonstração gerado pelo seed é lido", async () => {
  const pdf = join(__dirname, "../../../seed/assets/gerados/historico_demo_ana.pdf");
  if (!existsSync(pdf)) return;
  const h = parseHistorico(await textoDoPdf(pdf));
  assert.equal(h.disciplinas.length, 16);
  assert.equal(h.cursoCodigo, "65C");
  assert.equal(h.disciplinas.filter((d) => d.situacao === "cursando").length, 8);
});

// O histórico real (com dados pessoais) só existe na máquina de quem o forneceu e nunca é versionado.
test("histórico real do SIGA, se disponível localmente", async () => {
  const pdf = join(__dirname, "../../../seed/assets/historico_exemplo.pdf");
  if (!existsSync(pdf)) return;
  const h = parseHistorico(await textoDoPdf(pdf));
  assert.ok(h.disciplinas.length > 10);
  assert.ok(h.ira !== null && h.ira > 0 && h.ira <= 100);
  assert.ok(h.cursoCodigo);
  for (const d of h.disciplinas) {
    assert.match(d.codigo, /^[A-Z]{2,6}\d{3,4}$/);
    assert.ok(d.nome.length > 2, `nome vazio em ${d.codigo}`);
    assert.ok(d.situacao === "cursando" ? d.nota === null : d.nota !== null, `nota inconsistente em ${d.codigo}`);
  }
});

test("texto sem disciplinas gera erro orientativo", () => {
  assert.throws(() => parseHistorico("Declaração de matrícula\nNome: Fulano"), HistoricoInvalidoError);
});
