import { FieldValue } from "firebase-admin/firestore";
import { onDocumentCreated, onDocumentWritten } from "firebase-functions/firestore";
import { db, gerarKeywords, notificar, notificarAdmins, rotaPublicacao } from "./common";

function mesmasKeywords(a: unknown, b: string[]): boolean {
  return Array.isArray(a) && a.length === b.length && a.every((k, i) => k === b[i]);
}

/**
 * RF15 — mantém o índice de busca (`keywords`) de cada publicação.
 * RF07 — avisa os administradores quando entra conteúdo pendente de aprovação.
 */
export const onPublicacaoWritten = onDocumentWritten("publicacoes/{id}", async (event) => {
  const depois = event.data?.after;
  if (!depois?.exists) return;
  const p = depois.data()!;

  const keywords = gerarKeywords(p.titulo, p.categoria, p.local, p.autorNome);
  if (!mesmasKeywords(p.keywords, keywords)) {
    await depois.ref.update({ keywords });
  }

  const antes = event.data?.before;
  if (!antes?.exists && p.status === "pendente" && !p.seed) {
    await notificarAdmins({
      tipo: "moderacao",
      texto: `Novo conteúdo aguardando aprovação: "${p.titulo}"`,
      link: "/admin/moderacao",
    });
  }
});

/** RF15 — índice de busca dos materiais de estudo. */
export const onMaterialWritten = onDocumentWritten("materiais/{id}", async (event) => {
  const depois = event.data?.after;
  if (!depois?.exists) return;
  const m = depois.data()!;
  const keywords = gerarKeywords(m.titulo, m.disciplinaId, m.disciplinaNome, m.tipo);
  if (!mesmasKeywords(m.keywords, keywords)) {
    await depois.ref.update({ keywords });
  }
});

/** RF04/RF14 — atualiza contadores do tópico e avisa o autor sobre a nova resposta. */
export const onRespostaCreated = onDocumentCreated("publicacoes/{pubId}/respostas/{id}", async (event) => {
  const r = event.data?.data();
  // Dados do seed já chegam com contadores consolidados.
  if (!r || r.seed) return;
  const pubRef = db.collection("publicacoes").doc(event.params.pubId);
  await pubRef.update({
    respostasCount: FieldValue.increment(1),
    interacoes: FieldValue.increment(1),
    ultimaRespostaEm: FieldValue.serverTimestamp(),
  });
  const pub = await pubRef.get();
  const autorId = pub.get("autorId") as string | null;
  if (autorId && autorId !== r.autorId) {
    await notificar(autorId, {
      tipo: "resposta",
      texto: `${r.autorNome} respondeu "${pub.get("titulo")}"`,
      link: rotaPublicacao(pub.get("tipo"), pub.id),
    });
  }
});
