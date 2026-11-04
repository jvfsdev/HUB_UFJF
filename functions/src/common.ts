import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { CallableRequest, HttpsError } from "firebase-functions/https";

initializeApp();

export const db = getFirestore();
export const auth = getAuth();
export const storage = getStorage();

export type Perfil = "estudante" | "geral" | "externo" | "admin";
export const PERFIS: Perfil[] = ["estudante", "geral", "externo", "admin"];

/** Garante que a chamada vem de um usuário autenticado (e, opcionalmente, com um dos perfis). */
export function exigirPerfil(req: CallableRequest, ...perfis: Perfil[]): { uid: string; perfil: Perfil } {
  if (!req.auth) {
    throw new HttpsError("unauthenticated", "Faça login para continuar.");
  }
  const perfil = req.auth.token.role as Perfil | undefined;
  if (perfis.length > 0 && (!perfil || !perfis.includes(perfil))) {
    throw new HttpsError("permission-denied", "Seu perfil não tem permissão para esta ação.");
  }
  return { uid: req.auth.uid, perfil: perfil ?? "geral" };
}

/** Remove acentos e baixa a caixa, para indexação e busca (RF15). */
export function normalizar(texto: string): string {
  return texto.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

const STOPWORDS = new Set(["para", "com", "sem", "uma", "das", "dos", "que", "por", "nos", "nas", "the", "and"]);

/**
 * Gera tokens de busca: cada palavra com 3+ letras e seus prefixos (a partir de 3 letras),
 * permitindo busca "enquanto digita" com array-contains. A mesma função existe no app
 * (lib/core/busca.dart) — mantenha as duas em sincronia.
 */
export function gerarKeywords(...partes: (string | undefined | null)[]): string[] {
  const tokens = new Set<string>();
  for (const parte of partes) {
    if (!parte) continue;
    for (const palavra of normalizar(parte).split(/[^a-z0-9]+/)) {
      if (palavra.length < 3 || STOPWORDS.has(palavra)) continue;
      for (let i = 3; i <= Math.min(palavra.length, 15); i++) {
        tokens.add(palavra.slice(0, i));
      }
    }
  }
  return [...tokens].slice(0, 150);
}

export async function notificar(uid: string, n: { tipo: string; texto: string; link?: string }) {
  await db.collection("users").doc(uid).collection("notificacoes").add({
    ...n,
    lida: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

export async function notificarAdmins(n: { tipo: string; texto: string; link?: string }) {
  const admins = await db.collection("users").where("perfil", "==", "admin").get();
  await Promise.all(admins.docs.map((d) => notificar(d.id, n)));
}

/** Rota do app para uma publicação, usada nos links das notificações. */
export function rotaPublicacao(tipo: string, id: string): string {
  switch (tipo) {
    case "topico":
      return `/foruns/topico/${id}`;
    case "anuncio":
      return `/anuncios/${id}`;
    case "evento":
      return `/eventos/${id}`;
    case "orientacao":
      return `/orientacoes/${id}`;
    default:
      return "/home";
  }
}
