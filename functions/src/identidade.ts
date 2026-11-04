import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/https";
import { logger } from "firebase-functions";
import { auth, db, exigirPerfil, Perfil, storage } from "./common";

const DOMINIO_ESTUDANTE = "@estudante.ufjf.br";

/**
 * RF01 — completa o cadastro: valida o perfil escolhido, grava o documento do usuário
 * e define a custom claim `role`, usada pelas Security Rules (RNF07).
 */
export const completarCadastro = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Faça login para continuar.");
  const { nome, perfil, cursoId, consentimentoLGPD } = req.data as {
    nome?: string;
    perfil?: Perfil;
    cursoId?: string;
    consentimentoLGPD?: boolean;
  };
  const email = (req.auth.token.email ?? "").toLowerCase();

  if (!nome || nome.trim().length < 3) {
    throw new HttpsError("invalid-argument", "Informe seu nome completo.");
  }
  if (!perfil || !["estudante", "geral", "externo"].includes(perfil)) {
    throw new HttpsError("invalid-argument", "Selecione um perfil válido.");
  }
  if (perfil === "estudante" && !email.endsWith(DOMINIO_ESTUDANTE)) {
    throw new HttpsError(
      "failed-precondition",
      `O perfil Estudante exige um e-mail institucional (${DOMINIO_ESTUDANTE}).`,
    );
  }
  if (consentimentoLGPD !== true) {
    throw new HttpsError("failed-precondition", "É necessário aceitar a Política de Privacidade.");
  }

  const ref = db.collection("users").doc(req.auth.uid);
  const existente = await ref.get();
  if (existente.exists) {
    throw new HttpsError("already-exists", "Este cadastro já foi concluído.");
  }

  await ref.set({
    nome: nome.trim(),
    email,
    perfil,
    cursoId: perfil === "estudante" ? cursoId ?? null : null,
    consentimentoLGPD: true,
    consentimentoEm: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  });
  await auth.setCustomUserClaims(req.auth.uid, { role: perfil });
  logger.info("cadastro concluído", { uid: req.auth.uid, perfil });
  return { perfil };
});

/** RNF05 (LGPD) — portabilidade: devolve todos os dados pessoais do usuário. */
export const exportarDados = onCall(async (req) => {
  const { uid } = exigirPerfil(req);
  const user = await db.collection("users").doc(uid).get();
  const sub = async (nome: string) =>
    (await db.collection("users").doc(uid).collection(nome).get()).docs.map((d) => ({ id: d.id, ...d.data() }));
  const publicacoes = await db.collection("publicacoes").where("autorId", "==", uid).get();
  const materiais = await db.collection("materiais").where("autorId", "==", uid).get();
  const denuncias = await db.collection("denuncias").where("denuncianteId", "==", uid).get();

  const dados = {
    exportadoEm: new Date().toISOString(),
    observacao: "Avaliações são anônimas e não podem ser vinculadas à sua conta (RNF04).",
    usuario: user.data() ?? null,
    historico: await sub("historico"),
    notificacoes: await sub("notificacoes"),
    interacoes: await sub("interacoes"),
    publicacoes: publicacoes.docs.map((d) => ({ id: d.id, ...d.data() })),
    materiais: materiais.docs.map((d) => ({ id: d.id, ...d.data() })),
    denuncias: denuncias.docs.map((d) => ({ id: d.id, ...d.data() })),
  };
  // Timestamps do Firestore viram strings ISO.
  return JSON.parse(
    JSON.stringify(dados, (_k, v) => (v && typeof v.toDate === "function" ? v.toDate().toISOString() : v)),
  );
});

/** RNF05 (LGPD) — exclusão: apaga dados pessoais e anonimiza o conteúdo publicado. */
export const excluirConta = onCall(async (req) => {
  const { uid, perfil } = exigirPerfil(req);
  if (perfil === "admin") {
    throw new HttpsError("failed-precondition", "Contas de administrador não podem ser excluídas por aqui.");
  }
  const userRef = db.collection("users").doc(uid);
  for (const nome of ["historico", "notificacoes", "interacoes"]) {
    await db.recursiveDelete(userRef.collection(nome));
  }

  const anonimo = { autorId: null, autorNome: "Usuário removido" };
  const batch = db.bulkWriter();
  for (const col of ["publicacoes", "materiais"]) {
    const snap = await db.collection(col).where("autorId", "==", uid).get();
    snap.docs.forEach((d) => batch.update(d.ref, anonimo));
  }
  const respostas = await db.collectionGroup("respostas").where("autorId", "==", uid).get();
  respostas.docs.forEach((d) => batch.update(d.ref, anonimo));
  await batch.close();

  await storage.bucket().deleteFiles({ prefix: `historicos/${uid}/` }).catch(() => undefined);
  await userRef.delete();
  await auth.deleteUser(uid);
  logger.info("conta excluída (LGPD)", { uid });
  return { ok: true };
});
