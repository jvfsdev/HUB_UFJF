import { Timestamp } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/https";
import { onSchedule } from "firebase-functions/scheduler";
import { logger } from "firebase-functions";
import { db, exigirPerfil, notificar } from "./common";

const FUSO = "America/Sao_Paulo";

/** RF09 — eventos com data expirada são arquivados automaticamente. */
export async function arquivarEventosVencidos(agora = new Date()): Promise<number> {
  const vencidos = await db
    .collection("publicacoes")
    .where("tipo", "==", "evento")
    .where("status", "==", "aprovado")
    .where("dataEvento", "<", Timestamp.fromDate(agora))
    .get();
  const batch = db.batch();
  vencidos.docs.forEach((d) => batch.update(d.ref, { status: "arquivado" }));
  await batch.commit();
  return vencidos.size;
}

export const arquivarEventos = onSchedule({ schedule: "every day 00:05", timeZone: FUSO }, async () => {
  const n = await arquivarEventosVencidos();
  logger.info("eventos arquivados", { n });
});

const AREA_POR_TIPO: Record<string, string> = {
  topico: "foruns",
  anuncio: "anuncios",
  evento: "eventos",
  orientacao: "orientacoes",
};

/** Popularidade com decaimento temporal: interações valem 3x uma visualização. */
export function calcularScore(views: number, interacoes: number, criadoEm: Date, agora = new Date()): number {
  const idadeDias = Math.max(0, (agora.getTime() - criadoEm.getTime()) / 86_400_000);
  return (views + 3 * interacoes) / (1 + idadeDias / 14);
}

/**
 * RF10/RF15 — recalcula o índice `indices/popular`, lido pela home para montar as
 * recomendações. Conteúdo removido, pendente ou arquivado nunca entra no índice.
 */
export async function recalcularIndicePopular(): Promise<number> {
  const agora = new Date();
  const itens: Record<string, unknown>[] = [];

  const pubs = await db.collection("publicacoes").where("status", "==", "aprovado").limit(1000).get();
  for (const d of pubs.docs) {
    const p = d.data();
    itens.push({
      colecao: "publicacoes",
      id: d.id,
      tipo: p.tipo,
      area: AREA_POR_TIPO[p.tipo] ?? "foruns",
      titulo: p.titulo,
      categoria: p.categoria ?? null,
      resumo: String(p.conteudo ?? "").slice(0, 140),
      imagem: p.anexos?.find((a: { tipo?: string }) => a.tipo === "imagem")?.url ?? null,
      score: calcularScore(p.views ?? 0, p.interacoes ?? 0, p.createdAt?.toDate?.() ?? agora, agora),
    });
  }

  const mats = await db.collection("materiais").where("status", "==", "aprovado").limit(1000).get();
  for (const d of mats.docs) {
    const m = d.data();
    itens.push({
      colecao: "materiais",
      id: d.id,
      tipo: "material",
      area: "materiais",
      titulo: m.titulo,
      categoria: m.disciplinaId ?? null,
      resumo: m.descricao ? String(m.descricao).slice(0, 140) : (m.disciplinaNome ?? ""),
      imagem: null,
      score: calcularScore(m.views ?? 0, m.downloads ?? 0, m.createdAt?.toDate?.() ?? agora, agora),
    });
  }

  itens.sort((a, b) => (b.score as number) - (a.score as number));
  // Mantém os 15 melhores de cada área para que a personalização no app tenha material.
  const porArea: Record<string, number> = {};
  const selecionados = itens.filter((i) => {
    const area = i.area as string;
    porArea[area] = (porArea[area] ?? 0) + 1;
    return porArea[area] <= 15;
  });

  await db.collection("indices").doc("popular").set({
    itens: selecionados,
    atualizadoEm: Timestamp.fromDate(agora),
  });
  return selecionados.length;
}

export const recalcularPopularidade = onSchedule({ schedule: "every 60 minutes", timeZone: FUSO }, async () => {
  const n = await recalcularIndicePopular();
  logger.info("índice de popularidade recalculado", { n });
});

/** Permite ao administrador forçar a atualização dos índices (útil em demonstrações). */
export const atualizarIndicesAgora = onCall(async (req) => {
  exigirPerfil(req, "admin");
  const arquivados = await arquivarEventosVencidos();
  const itens = await recalcularIndicePopular();
  return { arquivados, itens };
});

/** RF14 (fluxo alternativo 1) — lembra estudantes de dúvidas sem resposta há mais de 24h. */
export const lembrarOrientacoesPendentes = onSchedule(
  { schedule: "every day 09:00", timeZone: FUSO },
  async () => {
    const limite = Timestamp.fromMillis(Date.now() - 24 * 3_600_000);
    const pendentes = await db
      .collection("publicacoes")
      .where("tipo", "==", "orientacao")
      .where("status", "==", "aprovado")
      .where("respostasCount", "==", 0)
      .where("createdAt", "<", limite)
      .get();
    const semLembrete = pendentes.docs.filter((d) => !d.get("lembreteEnviado"));
    if (semLembrete.length === 0) return;

    const estudantes = await db.collection("users").where("perfil", "==", "estudante").limit(200).get();
    for (const p of semLembrete) {
      await Promise.all(
        estudantes.docs.map((e) =>
          notificar(e.id, {
            tipo: "orientacao",
            texto: `Um futuro calouro ainda espera resposta: "${p.get("titulo")}"`,
            link: `/orientacoes/${p.id}`,
          }),
        ),
      );
      await p.ref.update({ lembreteEnviado: true });
    }
    logger.info("lembretes de orientação enviados", { perguntas: semLembrete.length });
  },
);
