import { createHmac } from "node:crypto";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/https";
import { defineSecret } from "firebase-functions/params";
import { db, exigirPerfil } from "./common";

const HMAC_SECRET = defineSecret("AVALIACAO_HMAC_SECRET");

const COLECAO_ALVO: Record<string, string> = {
  disciplina: "disciplinas",
  professor: "professores",
  projeto: "projetos",
};

/**
 * Identificador irreversível de "este estudante já avaliou este item".
 * Sem o segredo (guardado no Secret Manager) não é possível ligar um guard a um usuário,
 * e a avaliação em si não contém nenhum dado do autor (RNF04).
 */
export function guardId(segredo: string, uid: string, tipoAlvo: string, alvoId: string): string {
  return createHmac("sha256", segredo).update(`${uid}|${tipoAlvo}|${alvoId}`).digest("hex");
}

/** Data truncada ao dia, para que o horário exato não sirva de pista sobre o autor. */
function hojeSemHorario(): Timestamp {
  const d = new Date();
  d.setUTCHours(12, 0, 0, 0);
  return Timestamp.fromDate(d);
}

/**
 * RF05 — registra (ou edita) uma avaliação anônima. Apenas estudantes; uma por item.
 * Sem `editar`, se já houver avaliação, devolve `jaAvaliado` com a avaliação anterior
 * para que o app ofereça a edição (fluxo alternativo 1).
 */
export const enviarAvaliacao = onCall({ secrets: [HMAC_SECRET] }, async (req) => {
  const { uid } = exigirPerfil(req, "estudante");
  const { tipoAlvo, alvoId, nota, comentario, editar } = req.data as {
    tipoAlvo?: string;
    alvoId?: string;
    nota?: number;
    comentario?: string;
    editar?: boolean;
  };

  const colecao = tipoAlvo ? COLECAO_ALVO[tipoAlvo] : undefined;
  if (!colecao || !alvoId) throw new HttpsError("invalid-argument", "Item a ser avaliado inválido.");
  if (!Number.isInteger(nota) || nota! < 1 || nota! > 5) {
    throw new HttpsError("invalid-argument", "A nota deve ser um número inteiro de 1 a 5.");
  }
  const texto = (comentario ?? "").trim();
  if (texto.length > 1000) throw new HttpsError("invalid-argument", "O comentário não pode exceder 1000 caracteres.");

  const alvoRef = db.collection(colecao).doc(alvoId);
  const guardRef = db.collection("avaliacaoGuards").doc(guardId(HMAC_SECRET.value(), uid, tipoAlvo!, alvoId));

  return db.runTransaction(async (tx) => {
    const [alvo, guard] = await Promise.all([tx.get(alvoRef), tx.get(guardRef)]);
    if (!alvo.exists) throw new HttpsError("not-found", "O item avaliado não existe mais.");

    if (guard.exists) {
      const avaliacaoRef = db.collection("avaliacoes").doc(guard.get("avaliacaoId"));
      const anterior = await tx.get(avaliacaoRef);
      const notaAnterior = anterior.get("nota") as number;
      if (!editar) {
        return { jaAvaliado: true, nota: notaAnterior, comentario: anterior.get("comentario") ?? "" };
      }
      tx.update(avaliacaoRef, { nota, comentario: texto, editadaEm: hojeSemHorario() });
      const dist = { ...(alvo.get("distribuicao") ?? {}) } as Record<string, number>;
      dist[notaAnterior] = Math.max(0, (dist[notaAnterior] ?? 1) - 1);
      dist[nota!] = (dist[nota!] ?? 0) + 1;
      const soma = (alvo.get("somaNotas") ?? 0) - notaAnterior + nota!;
      const total = alvo.get("totalAvaliacoes") ?? 1;
      tx.update(alvoRef, { somaNotas: soma, mediaAvaliacao: soma / total, distribuicao: dist });
      return { jaAvaliado: false, editada: true };
    }

    const avaliacaoRef = db.collection("avaliacoes").doc();
    tx.set(avaliacaoRef, {
      tipoAlvo,
      alvoId,
      nota,
      comentario: texto,
      createdAt: hojeSemHorario(),
    });
    tx.set(guardRef, { avaliacaoId: avaliacaoRef.id });
    const soma = (alvo.get("somaNotas") ?? 0) + nota!;
    const total = (alvo.get("totalAvaliacoes") ?? 0) + 1;
    tx.update(alvoRef, {
      somaNotas: soma,
      totalAvaliacoes: total,
      mediaAvaliacao: soma / total,
      [`distribuicao.${nota}`]: FieldValue.increment(1),
    });
    return { jaAvaliado: false, editada: false };
  });
});
