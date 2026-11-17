import { FieldValue } from "firebase-admin/firestore";
import { onDocumentCreated } from "firebase-functions/firestore";
import { HttpsError, onCall } from "firebase-functions/https";
import { logger } from "firebase-functions";
import { db, exigirPerfil, notificar, notificarAdmins, rotaPublicacao } from "./common";

/** RF07 — o administrador aprova ou rejeita um conteúdo pendente de usuário externo. */
export const moderarPublicacao = onCall(async (req) => {
  const { uid } = exigirPerfil(req, "admin");
  const { id, decisao, motivo } = req.data as { id?: string; decisao?: string; motivo?: string };
  if (!id || !["aprovar", "rejeitar"].includes(decisao ?? "")) {
    throw new HttpsError("invalid-argument", "Decisão de moderação inválida.");
  }
  const ref = db.collection("publicacoes").doc(id);
  const pub = await ref.get();
  if (!pub.exists) throw new HttpsError("not-found", "Publicação não encontrada.");
  if (pub.get("status") !== "pendente") {
    throw new HttpsError("failed-precondition", "Esta publicação já foi moderada.");
  }

  const aprovado = decisao === "aprovar";
  await ref.update({
    status: aprovado ? "aprovado" : "rejeitado",
    moderacao: { por: uid, em: FieldValue.serverTimestamp(), motivo: motivo ?? null },
  });
  const autorId = pub.get("autorId") as string | null;
  if (autorId) {
    await notificar(autorId, {
      tipo: aprovado ? "aprovacao" : "rejeicao",
      texto: aprovado
        ? `Sua publicação "${pub.get("titulo")}" foi aprovada e já está visível.`
        : `Sua publicação "${pub.get("titulo")}" foi rejeitada${motivo ? `: ${motivo}` : "."}`,
      link: aprovado ? rotaPublicacao(pub.get("tipo"), id) : undefined,
    });
  }
  logger.info("publicação moderada", { id, decisao, admin: uid });
  return { ok: true };
});

/** RF12 — encaminha cada nova denúncia: incrementa o contador do alvo e avisa os admins. */
export const onDenunciaCreated = onDocumentCreated("denuncias/{id}", async (event) => {
  const d = event.data?.data();
  if (!d || d.seed) return;
  await db.doc(d.alvoPath).update({ denunciasCount: FieldValue.increment(1) }).catch(() => undefined);
  await notificarAdmins({
    tipo: "denuncia",
    texto: `Nova denúncia (${d.motivo}): "${d.alvoTitulo ?? "conteúdo"}"`,
    link: "/admin/denuncias",
  });
});

/**
 * RF12 — o administrador decide manter ou remover o conteúdo denunciado. Todas as
 * denúncias abertas do mesmo alvo são resolvidas juntas e os denunciantes são avisados.
 */
export const resolverDenuncia = onCall(async (req) => {
  const { uid } = exigirPerfil(req, "admin");
  const { denunciaId, decisao } = req.data as { denunciaId?: string; decisao?: string };
  if (!denunciaId || !["manter", "remover"].includes(decisao ?? "")) {
    throw new HttpsError("invalid-argument", "Decisão inválida.");
  }
  const denuncia = await db.collection("denuncias").doc(denunciaId).get();
  if (!denuncia.exists) throw new HttpsError("not-found", "Denúncia não encontrada.");
  const alvoPath = denuncia.get("alvoPath") as string;

  const abertas = await db
    .collection("denuncias")
    .where("alvoPath", "==", alvoPath)
    .where("status", "==", "aberta")
    .get();

  const batch = db.batch();
  if (decisao === "remover") {
    batch.update(db.doc(alvoPath), { status: "removido", removidoPor: uid });
  }
  for (const d of abertas.docs) {
    batch.update(d.ref, {
      status: "resolvida",
      decisao,
      resolvidaEm: FieldValue.serverTimestamp(),
      resolvidaPor: uid,
    });
  }
  await batch.commit();

  const titulo = denuncia.get("alvoTitulo") ?? "conteúdo";
  await Promise.all(
    abertas.docs.map((d) =>
      notificar(d.get("denuncianteId"), {
        tipo: "denuncia",
        texto:
          decisao === "remover"
            ? `O conteúdo "${titulo}" que você denunciou foi removido. Obrigado por ajudar!`
            : `Sua denúncia sobre "${titulo}" foi analisada e o conteúdo foi mantido.`,
      }),
    ),
  );
  logger.info("denúncia resolvida", { alvoPath, decisao, admin: uid, total: abertas.size });
  return { resolvidas: abertas.size };
});
