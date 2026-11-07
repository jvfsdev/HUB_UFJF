import { FieldValue } from "firebase-admin/firestore";
import { onObjectFinalized } from "firebase-functions/storage";
import { logger } from "firebase-functions";
import { PDFParse } from "pdf-parse";
import { db, storage } from "./common";
import { HistoricoInvalidoError, parseHistorico } from "./historico_parser";

/**
 * RF02 — quando o estudante envia o PDF do histórico para `historicos/{uid}/...`,
 * extrai as disciplinas e grava em `users/{uid}/historico/atual`. O app acompanha o
 * campo `status` (processando → ok | erro) em tempo real.
 */
export const onHistoricoUploaded = onObjectFinalized({ memory: "512MiB" }, async (event) => {
  const caminho = event.data.name;
  const match = caminho?.match(/^historicos\/([^/]+)\/[^/]+$/);
  if (!match) return;
  const uid = match[1];
  const ref = db.collection("users").doc(uid).collection("historico").doc("atual");

  if (event.data.contentType !== "application/pdf") {
    await ref.set({ status: "erro", erro: "Formato não suportado. Envie o histórico em PDF." }, { merge: true });
    return;
  }

  await ref.set({ status: "processando", arquivoPath: caminho, atualizadoEm: FieldValue.serverTimestamp() });
  try {
    const [buffer] = await storage.bucket(event.data.bucket).file(caminho!).download();
    const parser = new PDFParse({ data: buffer });
    const { text } = await parser.getText();
    await parser.destroy();

    const historico = parseHistorico(text);
    await ref.set({
      status: "ok",
      arquivoPath: caminho,
      disciplinas: historico.disciplinas,
      ira: historico.ira,
      matricula: historico.matricula,
      cursoCodigo: historico.cursoCodigo,
      erro: null,
      atualizadoEm: FieldValue.serverTimestamp(),
    });
    logger.info("histórico processado", { uid, disciplinas: historico.disciplinas.length });
  } catch (e) {
    const mensagem =
      e instanceof HistoricoInvalidoError
        ? e.message
        : "Não foi possível ler o arquivo. Verifique se o PDF não está protegido ou corrompido e tente novamente.";
    logger.error("falha ao processar histórico", { uid, caminho, erro: String(e) });
    await ref.set({ status: "erro", erro: mensagem, atualizadoEm: FieldValue.serverTimestamp() }, { merge: true });
  }
});
