import { setGlobalOptions } from "firebase-functions/options";

setGlobalOptions({ region: "southamerica-east1", maxInstances: 10 });

export { completarCadastro, exportarDados, excluirConta } from "./identidade";
export { enviarAvaliacao } from "./avaliacoes";
export { moderarPublicacao, resolverDenuncia, onDenunciaCreated } from "./moderacao";
export { onPublicacaoWritten, onMaterialWritten, onRespostaCreated } from "./publicacoes";
export {
  arquivarEventos,
  recalcularPopularidade,
  atualizarIndicesAgora,
  lembrarOrientacoesPendentes,
} from "./agendadas";
export { onHistoricoUploaded } from "./historico";
