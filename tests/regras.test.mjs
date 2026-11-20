// Testes das Security Rules (RNF07, RF05, RF07, RF11, RF12, RF13, RF14) no Emulator Suite.
// Pré-requisito: `firebase emulators:start --only firestore,storage` em execução.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, limit, query, serverTimestamp, setDoc, updateDoc, where, Timestamp, increment } from 'firebase/firestore';
import { ref, uploadBytes } from 'firebase/storage';

let env;
const PERMISSOES = {
  perfis: {
    estudante: Object.fromEntries(['foruns', 'anuncios', 'eventos', 'materiais', 'grade', 'avaliacoes', 'orientacoes'].map((a) => [a, { ler: true, publicar: true }])),
    geral: { foruns: { ler: true, publicar: true }, anuncios: { ler: true, publicar: true }, eventos: { ler: true, publicar: true },
      materiais: { ler: true, publicar: true }, grade: { ler: true, publicar: false }, avaliacoes: { ler: true, publicar: false },
      orientacoes: { ler: false, publicar: false } },
    externo: { orientacoes: { ler: true, publicar: true } },
  },
};

const como = (uid, role) => env.authenticatedContext(uid, { role, email: `${uid}@x.com` }).firestore();

const novaPublicacao = (uid, role, extra = {}) => ({
  tipo: 'topico', forumId: 'geral', titulo: 'Título válido', conteudo: 'Conteúdo', categoria: 'geral', anexos: [],
  autorId: uid, autorNome: uid, autorPerfil: role, status: role === 'externo' ? 'pendente' : 'aprovado',
  views: 0, interacoes: 0, respostasCount: 0, denunciasCount: 0, createdAt: serverTimestamp(), ...extra,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-hub-rules',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
    storage: { rules: readFileSync('../storage.rules', 'utf8'), host: '127.0.0.1', port: 9199 },
  });
});
after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'config/permissoes'), PERMISSOES);
    await setDoc(doc(db, 'publicacoes/topico1'), novaPublicacao('bruno', 'estudante', { createdAt: Timestamp.now() }));
    await setDoc(doc(db, 'publicacoes/orient1'), novaPublicacao('diego', 'externo', { tipo: 'orientacao', status: 'aprovado', createdAt: Timestamp.now() }));
    await setDoc(doc(db, 'avaliacoes/a1'), { tipoAlvo: 'professor', alvoId: 'p01', nota: 5, comentario: '', createdAt: Timestamp.now() });
  });
});

test('externo não lê tópicos, mas lê orientações (RF14)', async () => {
  const db = como('diego', 'externo');
  await assertFails(getDoc(doc(db, 'publicacoes/topico1')));
  await assertFails(getDocs(query(collection(db, 'publicacoes'), where('tipo', '==', 'topico'), where('status', '==', 'aprovado'))));
  await assertSucceeds(getDocs(query(collection(db, 'publicacoes'), where('tipo', '==', 'orientacao'), where('status', '==', 'aprovado'))));
});

test('conteúdo de externo nasce pendente (RF07)', async () => {
  const db = como('diego', 'externo');
  await assertFails(setDoc(doc(db, 'publicacoes/x1'), novaPublicacao('diego', 'externo', { tipo: 'orientacao', status: 'aprovado' })));
  await assertSucceeds(setDoc(doc(db, 'publicacoes/x2'), novaPublicacao('diego', 'externo', { tipo: 'orientacao' })));
});

test('perfil forjado no documento é recusado (RNF07)', async () => {
  const db = como('carla', 'geral');
  await assertFails(setDoc(doc(db, 'publicacoes/x3'), novaPublicacao('carla', 'admin')));
  await assertFails(setDoc(doc(db, 'publicacoes/x4'), novaPublicacao('outro', 'geral')));
  await assertSucceeds(setDoc(doc(db, 'publicacoes/x5'), novaPublicacao('carla', 'geral')));
});

test('conteúdo acima de 5000 caracteres é recusado (RF04)', async () => {
  const db = como('bruno', 'estudante');
  await assertFails(setDoc(doc(db, 'publicacoes/x6'), novaPublicacao('bruno', 'estudante', { conteudo: 'a'.repeat(5001) })));
});

test('evento com data passada é recusado (RF09)', async () => {
  const db = como('bruno', 'estudante');
  const evento = (d) => novaPublicacao('bruno', 'estudante', { tipo: 'evento', local: 'ICE', dataEvento: Timestamp.fromDate(d) });
  await assertFails(setDoc(doc(db, 'publicacoes/e1'), evento(new Date(Date.now() - 3 * 86_400_000))));
  await assertSucceeds(setDoc(doc(db, 'publicacoes/e2'), evento(new Date(Date.now() + 3 * 86_400_000))));
});

test('leitor só incrementa visualizações de 1 em 1 (RF10)', async () => {
  const db = como('ana', 'estudante');
  await assertSucceeds(updateDoc(doc(db, 'publicacoes/topico1'), { views: increment(1) }));
  await assertFails(updateDoc(doc(db, 'publicacoes/topico1'), { views: increment(50) }));
  await assertFails(updateDoc(doc(db, 'publicacoes/topico1'), { status: 'removido' }));
});

test('avaliações só são gravadas pela function e guards são inacessíveis (RF05/RNF04)', async () => {
  const db = como('ana', 'estudante');
  await assertSucceeds(getDoc(doc(db, 'avaliacoes/a1')));
  await assertFails(setDoc(doc(db, 'avaliacoes/a2'), { tipoAlvo: 'professor', alvoId: 'p01', nota: 5 }));
  await assertFails(getDoc(doc(db, 'avaliacaoGuards/qualquer')));
});

test('apenas admin altera permissões (RF13)', async () => {
  await assertFails(setDoc(doc(como('ana', 'estudante'), 'config/permissoes'), PERMISSOES));
  await assertSucceeds(setDoc(doc(como('admin', 'admin'), 'config/permissoes'), PERMISSOES));
});

test('denúncia duplicada é bloqueada e motivo é obrigatório (RF12)', async () => {
  const db = como('ana', 'estudante');
  const id = 'ana__publicacoes~topico1';
  const denuncia = { denuncianteId: 'ana', alvoPath: 'publicacoes/topico1', alvoTipo: 'topico', alvoTitulo: 't', motivo: 'spam', detalhes: '', status: 'aberta' };
  await assertFails(setDoc(doc(db, `denuncias/${id}`), { ...denuncia, motivo: 'qualquer' }));
  await assertSucceeds(setDoc(doc(db, `denuncias/${id}`), denuncia));
  await assertFails(setDoc(doc(db, `denuncias/${id}`), denuncia));
  await assertFails(setDoc(doc(db, 'denuncias/bruno__publicacoes~topico1'), { ...denuncia, denuncianteId: 'bruno' }));
});

test('usuário não altera o próprio perfil de acesso', async () => {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'users/ana'), { nome: 'Ana', perfil: 'estudante', cursoId: 'cc' }));
  const db = como('ana', 'estudante');
  await assertSucceeds(updateDoc(doc(db, 'users/ana'), { nome: 'Ana Clara' }));
  await assertFails(updateDoc(doc(db, 'users/ana'), { perfil: 'admin' }));
  await assertFails(getDoc(doc(como('bruno', 'estudante'), 'users/ana')));
});

test('storage valida tipo e tamanho dos uploads (RF11/RF02)', async () => {
  const st = env.authenticatedContext('ana', { role: 'estudante' }).storage();
  const bytes = (n) => new Uint8Array(n);
  await assertSucceeds(uploadBytes(ref(st, 'uploads/ana/foruns/a.pdf'), bytes(10), { contentType: 'application/pdf' }));
  await assertFails(uploadBytes(ref(st, 'uploads/ana/foruns/a.exe'), bytes(10), { contentType: 'application/x-msdownload' }));
  await assertFails(uploadBytes(ref(st, 'uploads/bruno/foruns/a.pdf'), bytes(10), { contentType: 'application/pdf' }));
  await assertFails(uploadBytes(ref(st, 'historicos/ana/h.png'), bytes(10), { contentType: 'image/png' }));
  await assertSucceeds(uploadBytes(ref(st, 'historicos/ana/h.pdf'), bytes(10), { contentType: 'application/pdf' }));
});
