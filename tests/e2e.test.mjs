// Fluxos ponta a ponta das Cloud Functions no Emulator Suite, com os dados do seed.
// Pré-requisito: emuladores rodando e `cd seed && npm run seed:emulador`.
import { strict as assert } from 'node:assert';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { deleteApp, initializeApp } from 'firebase/app';
import { connectAuthEmulator, createUserWithEmailAndPassword, getAuth, signInWithEmailAndPassword } from 'firebase/auth';
import { connectFirestoreEmulator, doc, getDoc, getFirestore, onSnapshot } from 'firebase/firestore';
import { connectFunctionsEmulator, getFunctions, httpsCallable } from 'firebase/functions';
import { connectStorageEmulator, getStorage, ref, uploadBytes } from 'firebase/storage';

const SENHA = 'HubUfjf@2026';

async function sessao(email, senha = SENHA, criar = false) {
  const app = initializeApp({ projectId: 'hub-ufjf', apiKey: 'demo', storageBucket: 'hub-ufjf.firebasestorage.app' }, email);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  const db = getFirestore(app);
  connectFirestoreEmulator(db, '127.0.0.1', 8080);
  const fn = getFunctions(app, 'southamerica-east1');
  connectFunctionsEmulator(fn, '127.0.0.1', 5001);
  const storage = getStorage(app);
  connectStorageEmulator(storage, '127.0.0.1', 9199);
  const cred = criar ? await createUserWithEmailAndPassword(auth, email, senha) : await signInWithEmailAndPassword(auth, email, senha);
  return { app, auth, db, storage, user: cred.user, call: (nome, dados) => httpsCallable(fn, nome)(dados).then((r) => r.data) };
}

const esperar = (db, caminho, cond, ms = 20000) => new Promise((resolve, reject) => {
  const t = setTimeout(() => { unsub(); reject(new Error(`timeout esperando ${caminho}`)); }, ms);
  const unsub = onSnapshot(doc(db, caminho), (s) => {
    if (s.exists() && cond(s.data())) { clearTimeout(t); unsub(); resolve(s.data()); }
  });
});

test('avaliação anônima: uma por item, segunda tentativa oferece edição (RF05)', async () => {
  const ana = await sessao('ana.estudante@estudante.ufjf.br');
  const antes = (await getDoc(doc(ana.db, 'disciplinas/DCC062'))).data();
  const r1 = await ana.call('enviarAvaliacao', { tipoAlvo: 'disciplina', alvoId: 'DCC062', nota: 5, comentario: 'Ótima!' });
  assert.deepEqual(r1, { jaAvaliado: false, editada: false });
  const r2 = await ana.call('enviarAvaliacao', { tipoAlvo: 'disciplina', alvoId: 'DCC062', nota: 3, comentario: '' });
  assert.equal(r2.jaAvaliado, true);
  assert.equal(r2.nota, 5);
  const r3 = await ana.call('enviarAvaliacao', { tipoAlvo: 'disciplina', alvoId: 'DCC062', nota: 4, comentario: 'Mudei de ideia', editar: true });
  assert.equal(r3.editada, true);
  const depois = (await getDoc(doc(ana.db, 'disciplinas/DCC062'))).data();
  assert.equal(depois.totalAvaliacoes, antes.totalAvaliacoes + 1);
  assert.equal(depois.somaNotas, antes.somaNotas + 4);
  await deleteApp(ana.app);
});

test('perfis não estudantes não podem avaliar', async () => {
  const carla = await sessao('carla@prestador.com');
  await assert.rejects(carla.call('enviarAvaliacao', { tipoAlvo: 'disciplina', alvoId: 'DCC199', nota: 5 }), /permission-denied|perfil/i);
  await deleteApp(carla.app);
});

test('importação do histórico em PDF é processada pela function (RF02)', async () => {
  const ana = await sessao('ana.estudante@estudante.ufjf.br');
  const pdf = readFileSync('../seed/assets/gerados/historico_demo_ana.pdf');
  await uploadBytes(ref(ana.storage, `historicos/${ana.user.uid}/teste.pdf`), pdf, { contentType: 'application/pdf' });
  const h = await esperar(ana.db, `users/${ana.user.uid}/historico/atual`, (d) => d.status === 'ok' || d.status === 'erro');
  assert.equal(h.status, 'ok', h.erro);
  assert.equal(h.disciplinas.length, 16);
  assert.equal(h.ira, 79.2);
  await deleteApp(ana.app);
});

test('cadastro: estudante exige e-mail institucional e recebe a claim (RF01)', async () => {
  const sufixo = Date.now();
  const s = await sessao(`teste${sufixo}@gmail.com`, 'senha-forte-123', true);
  await assert.rejects(s.call('completarCadastro', { nome: 'Teste Silva', perfil: 'estudante', consentimentoLGPD: true }), /institucional/);
  await assert.rejects(s.call('completarCadastro', { nome: 'Teste Silva', perfil: 'externo', consentimentoLGPD: false }), /Privacidade/);
  await s.call('completarCadastro', { nome: 'Teste Silva', perfil: 'externo', consentimentoLGPD: true });
  const token = await s.user.getIdTokenResult(true);
  assert.equal(token.claims.role, 'externo');
  await assert.rejects(s.call('completarCadastro', { nome: 'Teste Silva', perfil: 'geral', consentimentoLGPD: true }), /já foi concluído/);
  await deleteApp(s.app);
});

test('admin aprova conteúdo pendente e o autor é notificado (RF07)', async () => {
  const admin = await sessao('admin@hub-ufjf.dev');
  await admin.call('moderarPublicacao', { id: 'o-pend-vinicius', decisao: 'aprovar' });
  const p = (await getDoc(doc(admin.db, 'publicacoes/o-pend-vinicius'))).data();
  assert.equal(p.status, 'aprovado');
  await assert.rejects(admin.call('moderarPublicacao', { id: 'o-pend-vinicius', decisao: 'aprovar' }), /já foi moderada/);
  await deleteApp(admin.app);
});

test('não admin não modera', async () => {
  const bruno = await sessao('bruno.veterano@estudante.ufjf.br');
  await assert.rejects(bruno.call('moderarPublicacao', { id: 'o-pend-diego', decisao: 'aprovar' }), /permission-denied|perfil/i);
  await deleteApp(bruno.app);
});

test('denúncia resolvida remove o conteúdo e fecha todas as denúncias do alvo (RF12)', async () => {
  const admin = await sessao('admin@hub-ufjf.dev');
  const r = await admin.call('resolverDenuncia', { denunciaId: 'joao__publicacoes~t-spam', decisao: 'remover' });
  assert.equal(r.resolvidas, 2);
  const p = (await getDoc(doc(admin.db, 'publicacoes/t-spam'))).data();
  assert.equal(p.status, 'removido');
  await deleteApp(admin.app);
});

test('índices recalculados sob demanda arquivam eventos vencidos (RF09/RF10)', async () => {
  const admin = await sessao('admin@hub-ufjf.dev');
  const r = await admin.call('atualizarIndicesAgora');
  assert.ok(r.itens > 20);
  assert.ok(r.arquivados >= 1);
  const e = (await getDoc(doc(admin.db, 'publicacoes/e-estudo-algoritmos'))).data();
  assert.equal(e.status, 'arquivado');
  await deleteApp(admin.app);
});
