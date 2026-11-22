// Seed de demonstração do HUB-UFJF.
//   node seed.mjs --emulador [--reset]   → Emulator Suite local
//   node seed.mjs --prod [--reset]       → projeto hub-ufjf (requer `gcloud auth application-default login` com a conta dona do projeto)
import { randomUUID } from 'node:crypto';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const args = new Set(process.argv.slice(2));
const PROJETO = 'hub-ufjf';
const BUCKET = 'hub-ufjf.firebasestorage.app';
const EMULADOR = args.has('--emulador');

if (!EMULADOR && !args.has('--prod')) {
  console.error('Informe --emulador ou --prod.');
  process.exit(1);
}
if (EMULADOR) {
  process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
  process.env.FIREBASE_STORAGE_EMULATOR_HOST ??= '127.0.0.1:9199';
}

const { initializeApp } = await import('firebase-admin/app');
const { getAuth } = await import('firebase-admin/auth');
const { getFirestore, Timestamp } = await import('firebase-admin/firestore');
const { getStorage } = await import('firebase-admin/storage');
const academico = await import('./dados_academicos.mjs');
const comunidade = await import('./dados_comunidade.mjs');
const { gerarMaterial, gerarHistoricoAna } = await import('./pdfs.mjs');

initializeApp({ projectId: PROJETO, storageBucket: BUCKET });
const db = getFirestore();
const auth = getAuth();
const bucket = getStorage().bucket();
const SEED = { seed: true };

// ---------- utilidades ----------
const AGORA = new Date();
const diasAtras = (d, horas = 0) => Timestamp.fromDate(new Date(AGORA.getTime() - d * 86_400_000 + horas * 3_600_000));
const diaSemHorario = (d) => {
  const data = new Date(AGORA.getTime() - d * 86_400_000);
  data.setUTCHours(12, 0, 0, 0);
  return Timestamp.fromDate(data);
};

// Gerador pseudoaleatório determinístico, para o seed produzir sempre os mesmos dados.
let estado = 20260527;
const aleatorio = () => ((estado = (estado * 1103515245 + 12345) % 2 ** 31) / 2 ** 31);
const inteiro = (min, max) => Math.floor(aleatorio() * (max - min + 1)) + min;

// Mesma lógica de functions/src/common.ts (gerarKeywords).
const STOPWORDS = new Set(['para', 'com', 'sem', 'uma', 'das', 'dos', 'que', 'por', 'nos', 'nas', 'the', 'and']);
const normalizar = (t) => t.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
function keywords(...partes) {
  const tokens = new Set();
  for (const parte of partes) {
    if (!parte) continue;
    for (const palavra of normalizar(parte).split(/[^a-z0-9]+/)) {
      if (palavra.length < 3 || STOPWORDS.has(palavra)) continue;
      for (let i = 3; i <= Math.min(palavra.length, 15); i++) tokens.add(palavra.slice(0, i));
    }
  }
  return [...tokens].slice(0, 150);
}

const usuarios = Object.fromEntries(comunidade.usuarios.map(([uid, nome, email, perfil, cursoId]) => [uid, { uid, nome, email, perfil, cursoId }]));
const autor = (uid) => {
  const u = usuarios[uid];
  if (!u) throw new Error(`Usuário inexistente no seed: ${uid}`);
  return { autorId: u.uid, autorNome: u.nome, autorPerfil: u.perfil };
};
const nomeCurso = Object.fromEntries(academico.cursos.map((c) => [c.id, c.nome]));

async function emLotes(operacoes) {
  for (let i = 0; i < operacoes.length; i += 400) {
    const batch = db.batch();
    for (const [ref, dados] of operacoes.slice(i, i + 400)) batch.set(ref, dados);
    await batch.commit();
  }
}

// ---------- reset ----------
async function resetar() {
  const colecoes = ['users', 'cursos', 'disciplinas', 'departamentos', 'professores', 'projetos', 'foruns', 'publicacoes',
    'avaliacoes', 'avaliacaoGuards', 'materiais', 'denuncias', 'config', 'indices', 'logs'];
  for (const c of colecoes) await db.recursiveDelete(db.collection(c));
  for (const uid of Object.keys(usuarios)) {
    await auth.deleteUser(uid).catch(() => undefined);
  }
  await bucket.deleteFiles({ prefix: 'publico/' }).catch(() => undefined);
  console.log('✓ dados anteriores removidos');
}

// ---------- identidade ----------
async function semearUsuarios() {
  for (const u of Object.values(usuarios)) {
    await auth.createUser({
      uid: u.uid,
      email: u.email,
      password: comunidade.SENHA_DEMO,
      displayName: u.nome,
      emailVerified: true,
    }).catch(async (e) => {
      if (e.code !== 'auth/uid-already-exists' && e.code !== 'auth/email-already-exists') throw e;
      await auth.updateUser(u.uid, { password: comunidade.SENHA_DEMO, emailVerified: true });
    });
    await auth.setCustomUserClaims(u.uid, { role: u.perfil });
  }
  await emLotes(Object.values(usuarios).map((u, i) => [db.collection('users').doc(u.uid), {
    nome: u.nome,
    email: u.email,
    perfil: u.perfil,
    cursoId: u.cursoId,
    consentimentoLGPD: true,
    consentimentoEm: diasAtras(90 - i),
    createdAt: diasAtras(90 - i),
  }]));

  const todas = ['foruns', 'anuncios', 'eventos', 'materiais', 'grade', 'avaliacoes', 'orientacoes'];
  const matriz = (permitidas) => Object.fromEntries(todas.map((a) => [a, {
    ler: permitidas[a]?.includes('ler') ?? false,
    publicar: permitidas[a]?.includes('publicar') ?? false,
  }]));
  const ambas = ['ler', 'publicar'];
  await db.collection('config').doc('permissoes').set({
    perfis: {
      estudante: matriz(Object.fromEntries(todas.map((a) => [a, ambas]))),
      geral: matriz({ foruns: ambas, anuncios: ambas, eventos: ambas, materiais: ambas, grade: ['ler'], avaliacoes: ['ler'] }),
      externo: matriz({ orientacoes: ambas }),
    },
    atualizadoEm: Timestamp.now(),
  });
  console.log(`✓ ${Object.keys(usuarios).length} usuários (senha ${comunidade.SENHA_DEMO}) e permissões`);
}

// ---------- acadêmico ----------
const alvosAvaliacao = { disciplina: {}, professor: {}, projeto: {} };

async function semearAcademico() {
  const codigos = new Set(academico.disciplinas.map((d) => d.codigo));
  for (const d of academico.disciplinas) {
    for (const p of d.preRequisitos) if (!codigos.has(p)) throw new Error(`Pré-requisito ${p} de ${d.codigo} não existe`);
  }
  await emLotes(academico.cursos.map(({ id, ...curso }) => [db.collection('cursos').doc(id), curso]));
  await emLotes(academico.departamentos.map(({ id, ...d }) => [db.collection('departamentos').doc(id), d]));
  for (const { codigo, ...d } of academico.disciplinas) {
    alvosAvaliacao.disciplina[codigo] = {
      ref: db.collection('disciplinas').doc(codigo),
      dados: { ...d, keywords: keywords(codigo, d.nome) },
    };
  }
  for (const { id, ...p } of academico.professores) {
    alvosAvaliacao.professor[id] = { ref: db.collection('professores').doc(id), dados: p };
  }
  for (const { id, ...p } of academico.projetos) {
    alvosAvaliacao.projeto[id] = { ref: db.collection('projetos').doc(id), dados: p };
  }

  // Histórico do Bruno já processado (RF02); o da Ana é importado ao vivo na demonstração.
  const porCodigo = new Map();
  for (const [codigo, nome, situacao, nota, periodo] of academico.historicoBruno.disciplinas) {
    porCodigo.set(codigo, { codigo, nome, situacao, nota, periodo });
  }
  await db.collection('users').doc('bruno').collection('historico').doc('atual').set({
    status: 'ok',
    disciplinas: [...porCodigo.values()],
    ira: academico.historicoBruno.ira,
    matricula: academico.historicoBruno.matricula,
    cursoCodigo: academico.historicoBruno.curso,
    arquivoPath: null,
    erro: null,
    atualizadoEm: diasAtras(30),
  });
  console.log(`✓ ${academico.cursos.length} cursos, ${academico.disciplinas.length} disciplinas, ${academico.professores.length} professores, ` +
    `${academico.projetos.length} projetos, histórico do Bruno`);
}

// ---------- avaliações (RF05) ----------
async function semearAvaliacoes() {
  const ops = [];
  let total = 0;
  for (const [tipo, mapa] of Object.entries(comunidade.comentariosAvaliacao)) {
    for (const [alvoId, lista] of Object.entries(mapa)) {
      const alvo = alvosAvaliacao[tipo][alvoId];
      if (!alvo) throw new Error(`Alvo de avaliação inexistente: ${tipo}/${alvoId}`);
      const notas = lista.map(([n]) => n);
      // Notas sem comentário em torno da média, para engrossar a amostra.
      const media = notas.reduce((a, b) => a + b, 0) / notas.length;
      const extras = inteiro(1, 4);
      for (let i = 0; i < extras; i++) notas.push(Math.min(5, Math.max(1, Math.round(media + (aleatorio() - 0.5) * 2))));
      const comentarios = [...lista.map(([, c]) => c), ...Array(extras).fill('')];

      const dist = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
      notas.forEach((nota, i) => {
        dist[nota]++;
        ops.push([db.collection('avaliacoes').doc(), {
          tipoAlvo: tipo, alvoId, nota, comentario: comentarios[i], createdAt: diaSemHorario(inteiro(1, 120)),
        }]);
      });
      const soma = notas.reduce((a, b) => a + b, 0);
      Object.assign(alvo.dados, { somaNotas: soma, totalAvaliacoes: notas.length, mediaAvaliacao: soma / notas.length, distribuicao: dist });
      total += notas.length;
    }
  }
  for (const mapa of Object.values(alvosAvaliacao)) {
    for (const { ref, dados } of Object.values(mapa)) {
      ops.push([ref, { somaNotas: 0, totalAvaliacoes: 0, mediaAvaliacao: 0, distribuicao: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }, ...dados }]);
    }
  }
  await emLotes(ops);
  console.log(`✓ ${total} avaliações anônimas`);
}

// ---------- publicações ----------
const indicePopular = [];
function registrarPopular(item, views, interacoes, criadoEm) {
  const idade = Math.max(0, (AGORA.getTime() - criadoEm.toDate().getTime()) / 86_400_000);
  indicePopular.push({ ...item, score: (views + 3 * interacoes) / (1 + idade / 14) });
}

async function semearPublicacoes() {
  const ops = [];
  const pub = (id, dados) => ops.push([db.collection('publicacoes').doc(id), { ...SEED, ...dados }]);
  const resposta = (pubId, id, dados) => ops.push([db.collection('publicacoes').doc(pubId).collection('respostas').doc(id), { ...SEED, ...dados }]);

  ops.push(...comunidade.foruns.map(([id, nome, descricao, icone, cor], ordem) => [db.collection('foruns').doc(id), { nome, descricao, icone, cor, ordem }]));

  for (const t of comunidade.topicos) {
    const criado = diasAtras(t.dias);
    const interacoes = t.curtidas + t.respostas.length;
    pub(t.id, {
      tipo: 'topico', forumId: t.forum, categoria: t.forum, titulo: t.titulo, conteudo: t.conteudo, ...autor(t.autor),
      status: 'aprovado', anexos: [], views: t.views, interacoes, respostasCount: t.respostas.length, denunciasCount: 0,
      createdAt: criado, keywords: keywords(t.titulo, t.forum, null, usuarios[t.autor].nome),
    });
    t.respostas.forEach(([uid, texto, horas], i) => resposta(t.id, `r${i + 1}`, {
      conteudo: texto, ...autor(uid), cursoAutor: nomeCurso[usuarios[uid].cursoId] ?? null, status: 'aprovado',
      createdAt: diasAtras(t.dias, horas),
    }));
    if (t.id !== 't-spam') {
      registrarPopular({ colecao: 'publicacoes', id: t.id, tipo: 'topico', area: 'foruns', titulo: t.titulo, categoria: t.forum,
        resumo: t.conteudo.replace(/[#*_>|`-]/g, '').slice(0, 140), imagem: null }, t.views, interacoes, criado);
    }
  }
  // Resposta ofensiva que será denunciada (RF12).
  resposta('t-circular-lotacao', 'r-ofensiva', {
    conteudo: 'Esse motorista é um ****, deviam demitir.', ...autor('promo'), cursoAutor: null, status: 'aprovado', createdAt: diasAtras(5),
  });

  for (const [id, uid, categoria, titulo, conteudo, contato, preco, bairro, dias, views, curtidas] of comunidade.anuncios) {
    const criado = diasAtras(dias);
    pub(id, {
      tipo: 'anuncio', categoria, titulo, conteudo, contato, preco, bairro, ...autor(uid), status: 'aprovado', anexos: [],
      views, interacoes: curtidas, respostasCount: 0, denunciasCount: 0, createdAt: criado, keywords: keywords(titulo, categoria, null, usuarios[uid].nome),
    });
    registrarPopular({ colecao: 'publicacoes', id, tipo: 'anuncio', area: 'anuncios', titulo, categoria, resumo: conteudo.slice(0, 140), imagem: null },
      views, curtidas, criado);
  }
  for (const [id, uid, categoria, titulo, conteudo, contato, preco, bairro, dias] of comunidade.anunciosPendentes) {
    pub(id, {
      tipo: 'anuncio', categoria, titulo, conteudo, contato, preco, bairro, ...autor(uid), status: 'pendente', anexos: [],
      views: 0, interacoes: 0, respostasCount: 0, denunciasCount: 0, createdAt: diasAtras(dias, -2), keywords: keywords(titulo, categoria),
    });
  }

  for (const [id, uid, categoria, titulo, conteudo, quando, hora, local, projetoId, status = 'aprovado'] of comunidade.eventos) {
    // Datas reais são no fuso de Brasília (UTC−3).
    const data = typeof quando === 'string'
      ? new Date(`${quando}T${String(hora).padStart(2, '0')}:00:00-03:00`)
      : new Date(AGORA.getTime() + quando * 86_400_000);
    if (typeof quando !== 'string') data.setHours(hora, 0, 0, 0);
    const dias = Math.round((data.getTime() - AGORA.getTime()) / 86_400_000);
    const criado = diasAtras(Math.min(60, Math.max(2, -dias + 10)));
    const views = inteiro(30, 220);
    const interacoes = inteiro(2, 25);
    pub(id, {
      tipo: 'evento', categoria, titulo, conteudo, local, projetoId, dataEvento: Timestamp.fromDate(data), ...autor(uid), status,
      anexos: [], views, interacoes, respostasCount: 0, denunciasCount: 0, createdAt: criado, keywords: keywords(titulo, categoria, local, usuarios[uid].nome),
    });
    if (status === 'aprovado' && dias >= 0) {
      registrarPopular({ colecao: 'publicacoes', id, tipo: 'evento', area: 'eventos', titulo, categoria, resumo: conteudo.slice(0, 140), imagem: null },
        views, interacoes, criado);
    }
  }

  for (const [id, uid, titulo, conteudo, cursoInteresse, dias, status, respostas] of comunidade.orientacoes) {
    const criado = diasAtras(dias, -1);
    pub(id, {
      tipo: 'orientacao', categoria: null, cursoInteresse, titulo, conteudo, ...autor(uid), status, anexos: [],
      views: status === 'aprovado' ? inteiro(10, 80) : 0, interacoes: respostas.length, respostasCount: respostas.length,
      denunciasCount: 0, lembreteEnviado: false, createdAt: criado, keywords: keywords(titulo, null, null, usuarios[uid].nome),
    });
    respostas.forEach(([r, texto, horas], i) => resposta(id, `r${i + 1}`, {
      conteudo: texto, ...autor(r), cursoAutor: nomeCurso[usuarios[r].cursoId] ?? null, status: 'aprovado', createdAt: diasAtras(dias, horas),
    }));
  }

  await emLotes(ops);
  console.log(`✓ ${comunidade.foruns.length} fóruns, ${comunidade.topicos.length} tópicos, ${comunidade.anuncios.length + comunidade.anunciosPendentes.length} anúncios, ` +
    `${comunidade.eventos.length} eventos, ${comunidade.orientacoes.length} orientações`);
}

// ---------- materiais (RF08, RF11) ----------
function urlDownload(caminho, token) {
  const base = EMULADOR ? `http://127.0.0.1:9199` : 'https://firebasestorage.googleapis.com';
  return `${base}/v0/b/${BUCKET}/o/${encodeURIComponent(caminho)}?alt=media&token=${token}`;
}

async function semearMateriais() {
  const nomes = Object.fromEntries(academico.disciplinas.map((d) => [d.codigo, d.nome]));
  const ops = [];
  for (const [id, uid, disciplinaId, tipo, titulo, descricao, origem, dias, views, downloads] of comunidade.materiais) {
    let url = origem;
    let tamanho = null;
    if (origem.startsWith('pdf:')) {
      const chave = origem.slice(4);
      const local = await gerarMaterial(chave);
      const destino = `publico/materiais/${chave}.pdf`;
      const token = randomUUID();
      const [arquivo] = await bucket.upload(local, {
        destination: destino,
        metadata: { contentType: 'application/pdf', metadata: { firebaseStorageDownloadTokens: token } },
      });
      tamanho = Number(arquivo.metadata.size ?? 0);
      url = urlDownload(destino, token);
    }
    const criado = diasAtras(dias);
    ops.push([db.collection('materiais').doc(id), {
      ...SEED, titulo, descricao, tipo, disciplinaId, disciplinaNome: nomes[disciplinaId] ?? '', url, tamanho,
      autorId: uid, autorNome: usuarios[uid].nome, status: 'aprovado', views, downloads, denunciasCount: 0, createdAt: criado,
      keywords: keywords(titulo, disciplinaId, nomes[disciplinaId], tipo),
    }]);
    registrarPopular({ colecao: 'materiais', id, tipo: 'material', area: 'materiais', titulo, categoria: disciplinaId,
      resumo: descricao || nomes[disciplinaId], imagem: null }, views, downloads, criado);
  }
  await emLotes(ops);
  console.log(`✓ ${comunidade.materiais.length} materiais (PDFs enviados ao Storage)`);
}

// ---------- moderação, interações, notificações e índices ----------
async function semearRestante() {
  const ops = [];
  for (const [uid, alvoPath, alvoTipo, alvoTitulo, motivo, detalhes, trecho] of comunidade.denuncias) {
    ops.push([db.collection('denuncias').doc(`${uid}__${alvoPath.replaceAll('/', '~')}`), {
      ...SEED, denuncianteId: uid, alvoPath, alvoTipo, alvoTitulo, alvoTrecho: trecho, motivo, detalhes, status: 'aberta', createdAt: diasAtras(0, -inteiro(1, 20)),
    }]);
  }

  const interacoes = {
    bruno: { materiais: 42, foruns: 25, eventos: 6, anuncios: 3, grade: 10 },
    ana: { foruns: 2 },
    isabela: { materiais: 20, foruns: 10 },
    fernanda: { anuncios: 12, eventos: 8 },
  };
  for (const [uid, areas] of Object.entries(interacoes)) {
    for (const [area, total] of Object.entries(areas)) {
      ops.push([db.collection('users').doc(uid).collection('interacoes').doc(area), { total, atualizadoEm: diasAtras(1) }]);
    }
  }

  const notificacoes = [
    ['ana', 'orientacao', 'Bem-vinda ao HUB-UFJF! Importe seu histórico do SIGA para personalizar sua grade.', '/grade/historico', 1, false],
    ['ana', 'resposta', 'Bruno Henrique Teixeira respondeu "Qual o melhor horário para evitar fila no RU?"', '/foruns/topico/t-ru-horario', 12, true],
    ['bruno', 'resposta', 'Ana Clara Souza Martins respondeu "Como sobreviver a Cálculo I (de quem reprovou uma vez)"', '/foruns/topico/t-calculo-dicas', 25, false],
    ['bruno', 'orientacao', 'Um futuro calouro ainda espera resposta: "Preciso ser muito bom em matemática para fazer Engenharia Computacional?"', '/orientacoes/o-matematica-base', 1, false],
    ['diego', 'aprovacao', 'Sua publicação "Ciência da Computação ou Sistemas de Informação?" foi aprovada e já está visível.', '/orientacoes/o-cc-mercado', 10, true],
    ['diego', 'resposta', 'Bruno Henrique Teixeira respondeu "Ciência da Computação ou Sistemas de Informação?"', '/orientacoes/o-cc-mercado', 9, false],
    ['admin', 'moderacao', 'Novo conteúdo aguardando aprovação: "Alguém pode me mostrar o campus num sábado?"', '/admin/moderacao', 0, false],
    ['admin', 'moderacao', 'Novo conteúdo aguardando aprovação: "Procuro república para 2027 (aprovada no PISM)"', '/admin/moderacao', 0, false],
    ['admin', 'denuncia', 'Nova denúncia (spam): "GANHE R$ 500 POR DIA TRABALHANDO DE CASA!!!"', '/admin/denuncias', 0, false],
    ['admin', 'denuncia', 'Nova denúncia (ofensivo): "Resposta em "Circular das 18h está pulando o ponto do ICB?""', '/admin/denuncias', 0, false],
  ];
  for (const [uid, tipo, texto, link, dias, lida] of notificacoes) {
    ops.push([db.collection('users').doc(uid).collection('notificacoes').doc(), { tipo, texto, link, lida, createdAt: diasAtras(dias, -1) }]);
  }

  // RF10/RF15 — índice inicial (depois mantido pela function `recalcularPopularidade`).
  indicePopular.sort((a, b) => b.score - a.score);
  const porArea = {};
  const itens = indicePopular.filter((i) => (porArea[i.area] = (porArea[i.area] ?? 0) + 1) <= 15);
  ops.push([db.collection('indices').doc('popular'), { itens, atualizadoEm: Timestamp.now() }]);

  await emLotes(ops);
  console.log(`✓ ${comunidade.denuncias.length} denúncias abertas, interações, ${notificacoes.length} notificações, índice com ${itens.length} itens`);
}

console.log(`Semeando ${EMULADOR ? 'EMULADOR' : `PRODUÇÃO (${PROJETO})`}...`);
if (args.has('--reset')) await resetar();
await semearUsuarios();
await semearAcademico();
await semearAvaliacoes();
await semearPublicacoes();
await semearMateriais();
await semearRestante();
console.log('Pronto! Contas: ' + Object.values(usuarios).slice(0, 5).map((u) => u.email).join(', '));
await gerarHistoricoAna();
console.log(`PDF de histórico para a demo: ${join(dirname(fileURLToPath(import.meta.url)), 'assets/gerados/historico_demo_ana.pdf')}`);
process.exit(0);
