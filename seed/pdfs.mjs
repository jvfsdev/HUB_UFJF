// Gera os PDFs usados no seed: materiais de estudo de exemplo e o histórico
// escolar da Ana no layout de texto esperado pelo parser (functions/src/historico_parser.ts).
import { createWriteStream, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import PDFDocument from 'pdfkit';
import { historicoAna } from './dados_academicos.mjs';

const ASSETS = join(dirname(fileURLToPath(import.meta.url)), 'assets');
const GERADOS = join(ASSETS, 'gerados');

function salvar(doc, caminho) {
  return new Promise((resolve, reject) => {
    const stream = createWriteStream(caminho);
    stream.on('finish', () => resolve(caminho));
    stream.on('error', reject);
    doc.pipe(stream);
    doc.end();
  });
}

function cabecalho(doc, titulo, subtitulo) {
  doc.fillColor('#0B3D91').fontSize(10).text('HUB-UFJF · Material compartilhado pela comunidade', { align: 'right' });
  doc.moveDown(0.5);
  doc.fillColor('#000').fontSize(20).text(titulo);
  if (subtitulo) doc.fillColor('#555').fontSize(11).text(subtitulo);
  doc.moveDown();
  doc.fillColor('#000').fontSize(11);
}

const CONTEUDOS = {
  lista_limites: ['Lista 1 – Limites e continuidade', 'MAT154 · Cálculo I', [
    '1) Calcule lim (x→2) (x² − 4)/(x − 2).  Resolução: fatorando, (x−2)(x+2)/(x−2) = x+2 → 4.',
    '2) Calcule lim (x→0) sen(x)/x.  Resolução: limite fundamental trigonométrico → 1.',
    '3) Verifique a continuidade de f(x) = |x|/x em x = 0.  Resolução: limites laterais −1 e 1 diferem → descontínua.',
    '4) Calcule lim (x→∞) (3x² + 1)/(x² − 5).  Resolução: dividindo por x² → 3.',
    '5) Encontre a para que f seja contínua: f(x) = ax + 1 se x < 1; x² se x ≥ 1.  Resolução: a + 1 = 1 → a = 0.',
  ]],
  prova_calculo: ['Prova 1 – Cálculo I (2025/1)', 'MAT154 · Duração: 100 minutos', [
    'Questão 1 (2,5 pts): Calcule os limites (a) lim (x→3) (x²−9)/(x−3); (b) lim (x→0) (1−cos x)/x².',
    'Questão 2 (2,5 pts): Determine a derivada de f(x) = x³·ln(x) e de g(x) = e^(2x)/(1+x²).',
    'Questão 3 (2,5 pts): Encontre a reta tangente a y = √x no ponto x = 4.',
    'Questão 4 (2,5 pts): Um tanque cônico é esvaziado a 2 m³/min. Com que velocidade o nível desce quando h = 3 m?',
    '',
    'Gabarito: 1a) 6; 1b) 1/2; 2) f\'(x) = 3x²ln x + x², g\'(x) = e^(2x)(2+2x²−2x)/(1+x²)²; 3) y = x/4 + 1; 4) depende de r/h.',
  ]],
  resumo_integracao: ['Resumo – Técnicas de integração', 'MAT156 · Cálculo II', [
    'Substituição: ∫ f(g(x))g\'(x) dx = ∫ f(u) du.',
    'Por partes: ∫ u dv = uv − ∫ v du (regra LIATE para escolher u).',
    'Frações parciais: decomponha P(x)/Q(x) conforme os fatores de Q(x).',
    'Substituição trigonométrica: √(a²−x²) → x = a sen θ; √(a²+x²) → x = a tg θ.',
  ]],
  lista_ga: ['Lista – Vetores e retas', 'MAT155 · Geometria Analítica e Sistemas Lineares', [
    '1) Dados u = (1, 2, −1) e v = (3, 0, 4), calcule u·v e u×v.',
    '2) Encontre a equação da reta que passa por A(1, 1, 0) e B(2, −1, 3).',
    '3) Determine a distância do ponto P(1, 2, 3) ao plano x + y + z = 1.',
    'Respostas: 1) −1 e (8, −7, −6); 2) (1,1,0) + t(1,−2,3); 3) 5/√3.',
  ]],
  prova_algoritmos: ['Prova 2 – Algoritmos I (2025/3)', 'DCC199', [
    '1) Escreva uma função que receba um vetor de inteiros e retorne o segundo maior elemento.',
    '2) Implemente a multiplicação de duas matrizes 3×3.',
    '3) Faça uma função recursiva que calcule a soma dos dígitos de um número.',
    '4) Simule a execução do trecho de código fornecido e indique a saída.',
  ]],
  lista_algoritmos: ['Lista – Laços e funções', 'DCC199 · Algoritmos I', [
    '1) Leia N números e imprima a média dos positivos.',
    '2) Verifique se um número é primo usando uma função.',
    '3) Imprima os N primeiros termos da sequência de Fibonacci.',
    '4) Calcule o MDC de dois números pelo algoritmo de Euclides.',
    '5) Inverta os elementos de um vetor sem usar vetor auxiliar.',
  ]],
  resumo_recursao: ['Resumo – Recursividade e ordenação', 'DCC200 · Algoritmos II', [
    'Recursão: caso base + chamada recursiva que reduz o problema.',
    'Merge sort: divide ao meio, ordena recursivamente e intercala — O(n log n) sempre.',
    'Quick sort: escolhe pivô e particiona — O(n log n) em média, O(n²) no pior caso.',
    'Insertion sort: ótimo para vetores pequenos ou quase ordenados.',
  ]],
  prova_ed: ['Prova 1 – Estrutura de Dados (2025/1)', 'DCC013', [
    '1) Implemente a inserção ordenada em uma lista simplesmente encadeada.',
    '2) Usando uma pilha, verifique se uma expressão tem parênteses balanceados.',
    '3) Implemente uma fila circular com vetor e as operações enfileirar/desenfileirar.',
    '4) Qual a complexidade de busca em uma lista encadeada ordenada? Justifique.',
  ]],
  lista_poo: ['Lista – Herança e polimorfismo', 'DCC025 · Orientação a Objetos', [
    '1) Modele as classes Forma, Circulo e Retangulo com o método abstrato area().',
    '2) Crie uma hierarquia de Funcionario com cálculo de salário polimórfico.',
    '3) Explique a diferença entre sobrecarga e sobrescrita com exemplos em Java.',
  ]],
  resumo_grafos: ['Resumo – Teoria dos Grafos', 'DCC059', [
    'BFS: menor caminho em grafos não ponderados — O(V + E).',
    'DFS: componentes conexas, ordenação topológica, pontes e articulações.',
    'Dijkstra: caminho mínimo com pesos não negativos — O((V + E) log V).',
    'Kruskal / Prim: árvore geradora mínima.',
    'Ford-Fulkerson: fluxo máximo e corte mínimo.',
  ]],
  prova_bd: ['Prova – Normalização', 'DCC060 · Banco de Dados', [
    '1) Normalize até a 3FN a relação Pedido(num, data, cliente, endCliente, produto, qtd, preco).',
    '2) Mostre um exemplo de relação que está na 3FN mas não na FNBC.',
    '3) Escreva a consulta SQL que retorna os 5 clientes com maior valor total de pedidos.',
  ]],
  modelo_requisitos: ['Modelo de Documento de Requisitos', 'DCC061 · Engenharia de Software', [
    '1. Prefácio e histórico de versões',
    '2. Introdução e estudo de viabilidade',
    '3. Glossário',
    '4. Requisitos de usuário (funcionais e não funcionais)',
    '5. Arquitetura do sistema',
    '6. Requisitos de sistema em formato de casos de uso expandidos',
    '7. Modelos do sistema (casos de uso, classes, DER, DFD)',
    '8. Evolução do sistema e apêndices',
  ]],
  lista_estatistica: ['Lista – Probabilidade', 'EST028 · Introdução à Estatística', [
    '1) Uma moeda é lançada 10 vezes. Qual a probabilidade de exatamente 6 caras?  R: C(10,6)/2^10 ≈ 0,205.',
    '2) X ~ N(50, 25). Calcule P(X > 60).  R: P(Z > 2) ≈ 0,0228.',
    '3) Um dado é lançado até sair 6. Qual o número esperado de lançamentos?  R: 6.',
  ]],
  lista_fisica: ['Lista – Cinemática e dinâmica', 'FIS073 · Física I', [
    '1) Um carro acelera de 0 a 100 km/h em 8 s. Calcule a aceleração média.',
    '2) Um bloco de 2 kg desliza em plano inclinado de 30° sem atrito. Calcule a aceleração.',
    '3) Um projétil é lançado a 20 m/s com ângulo de 45°. Calcule o alcance.',
  ]],
};

// As fontes padrão do PDF (WinAnsi) não têm alguns símbolos matemáticos.
const SUBSTITUICOES = { '→': '->', '√': 'raiz', 'θ': 'theta', '∫': 'integral', '≈': '~', '−': '-', '∞': 'infinito', '≥': '>=' };
const textoSeguro = (t) => t.replace(/[→√θ∫≈−∞≥]/g, (c) => SUBSTITUICOES[c]);

export async function gerarMaterial(chave) {
  mkdirSync(GERADOS, { recursive: true });
  const [titulo, subtitulo, linhas] = CONTEUDOS[chave];
  const doc = new PDFDocument({ size: 'A4', margin: 56, info: { Title: titulo, Author: 'HUB-UFJF' } });
  cabecalho(doc, titulo, subtitulo);
  for (const l of linhas) {
    doc.text(textoSeguro(l), { paragraphGap: 10, lineGap: 2 });
  }
  return salvar(doc, join(GERADOS, `${chave}.pdf`));
}

/**
 * Histórico fictício no mesmo layout do SIGA (ver functions/src/historico_parser.ts):
 *   ANO SEM [CÓDIGO] NOME NOTA RESULTADO CH
 */
export async function gerarHistoricoAna() {
  mkdirSync(GERADOS, { recursive: true });
  const h = historicoAna;
  const doc = new PDFDocument({ size: 'A4', margin: 48, info: { Title: 'Histórico Escolar', Author: 'CDARA - UFJF' } });
  doc.font('Helvetica').fontSize(9).text('CAMPUS UNIVERSITÁRIO - SÃO PEDRO - JUIZ DE FORA - MG', { align: 'center' });
  doc.text('COORDENAÇÃO DE REGISTROS ACADÊMICOS (CDARA)', { align: 'center' });
  doc.font('Helvetica-Bold').fontSize(12).text('UNIVERSIDADE FEDERAL DE JUIZ DE FORA', { align: 'center' });
  doc.text('HISTÓRICO ESCOLAR', { align: 'center' });
  doc.moveDown(0.5).font('Helvetica').fontSize(9);
  doc.text(`MATRÍCULA: ${h.matricula}    NOME: ${h.nome.toUpperCase()}`);
  doc.text(`CURSO: ${h.curso}`);
  doc.text('NÍVEL: GRADUACAO PERÍODO: INTEGRAL');
  doc.text(`ÍNDICE DE RENDIMENTO ACADÊMICO: ${h.ira.toFixed(2).replace('.', ',')}`);
  doc.text('DOCUMENTO DE DEMONSTRAÇÃO - DADOS FICTÍCIOS');
  doc.moveDown(0.5).font('Helvetica-Bold').text('ANO DISCIPLINA HORAS/AULA    RESULTADO    SEM NOTA');
  doc.font('Helvetica');
  for (const [periodo, codigo, nome, ch, nota, situacao] of h.disciplinas) {
    const [ano, sem] = periodo.split('/');
    doc.text(`${ano} ${sem} [${codigo}] ${nome.toUpperCase()} ${nota == null ? '' : `${Math.round(nota)} `}${situacao} ${ch}`);
  }
  doc.moveDown().text('Pág. 1');
  doc.moveDown().fontSize(8).fillColor('#555').text(`Histórico acadêmico parcial para simples conferência. Emitido em ${new Date().toLocaleDateString('pt-BR')}.`);
  return salvar(doc, join(GERADOS, 'historico_demo_ana.pdf'));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const arquivos = await Promise.all([...Object.keys(CONTEUDOS).map(gerarMaterial), gerarHistoricoAna()]);
  console.log(`${arquivos.length} PDFs gerados em ${GERADOS}`);
}
