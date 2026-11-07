import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors.dart';
import '../../../core/widgets/comum.dart';
import '../../../models/academico.dart';
import '../../../models/usuario.dart';
import '../../identidade/data/identidade_repository.dart';
import '../data/academico_repository.dart';

/// RF02 — importação do histórico escolar em PDF.
class HistoricoPage extends ConsumerStatefulWidget {
  const HistoricoPage({super.key});

  @override
  ConsumerState<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends ConsumerState<HistoricoPage> {
  double? _progresso;
  String? _erro;

  Future<void> _enviar() async {
    final u = ref.read(usuarioAtualProvider)!;
    setState(() => _erro = null);
    final arquivos = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (arquivos.isEmpty) return;
    try {
      final arquivo = arquivos.first;
      final bytes = await arquivo.xFile.readAsBytes();
      setState(() => _progresso = 0);
      await for (final p
          in ref
              .read(academicoRepositoryProvider)
              .enviarHistorico(u.uid, arquivo.name, bytes)) {
        if (mounted) setState(() => _progresso = p);
      }
    } catch (e, st) {
      if (e is! AppException) LogService.registrar(e, st, nivel: 'historico');
      setState(() => _erro = mensagemErro(e));
    } finally {
      if (mounted) setState(() => _progresso = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final u = ref.watch(usuarioAtualProvider)!;
    if (u.perfil != Perfil.estudante) {
      return const EstadoVazio(
        icone: Icons.lock_outline,
        titulo: 'Disponível apenas para estudantes matriculados',
      );
    }
    final historico = ref.watch(meuHistoricoProvider);

    return Pagina(
      maxWidth: 860,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/grade'),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Grade curricular'),
          ),
        ),
        const CabecalhoPagina(
          titulo: 'Histórico escolar',
          subtitulo:
              'Importe o PDF emitido pelo SIGA para personalizar sua grade',
          icone: Icons.upload_file_outlined,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Como obter o arquivo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'No SIGA, acesse Acadêmico → Histórico Escolar → Gerar PDF. Envie o arquivo original, sem editar ou digitalizar.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _progresso == null ? _enviar : null,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Selecionar PDF do histórico'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Somente PDF, até 10 MB. O arquivo fica visível apenas para você.',
                  style: t.textTheme.bodySmall,
                ),
                if (_progresso != null) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _progresso),
                  Text('Enviando... ${(_progresso! * 100).round()}%'),
                ],
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  AvisoStatus(
                    icone: Icons.error_outline,
                    cor: t.colorScheme.error,
                    texto: _erro!,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AsyncView(
          value: historico,
          data: (h) => switch (h) {
            null => const SizedBox.shrink(),
            HistoricoEscolar(status: 'processando') => const Card(
              child: ListTile(
                leading: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text('Processando seu histórico...'),
                subtitle: Text('Isso leva alguns segundos.'),
              ),
            ),
            HistoricoEscolar(status: 'erro', :final erro) => AvisoStatus(
              icone: Icons.error_outline,
              cor: t.colorScheme.error,
              texto:
                  '${erro ?? 'Não foi possível processar o arquivo.'} Verifique o arquivo e tente novamente.',
            ),
            _ => _Resultado(h),
          },
        ),
      ],
    );
  }
}

class _Resultado extends StatelessWidget {
  const _Resultado(this.h);

  final HistoricoEscolar h;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final porPeriodo = <String, List<DisciplinaHistorico>>{};
    for (final d in h.disciplinas) {
      porPeriodo.putIfAbsent(d.periodo ?? 'Sem período', () => []).add(d);
    }
    final periodos = porPeriodo.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AvisoStatus(
          icone: Icons.check_circle_outline,
          cor: const Color(0xFF2E7D32),
          texto:
              'Histórico importado: ${h.disciplinas.length} disciplinas'
              '${h.ira != null ? ' · IRA ${h.ira!.toStringAsFixed(1)}' : ''}'
              '${h.atualizadoEm != null ? ' · ${tempoRelativo(h.atualizadoEm!)}' : ''}.',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () => context.go('/grade'),
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('Ver minha grade'),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Confira os dados extraídos',
          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final p in periodos)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      p,
                      style: t.textTheme.labelLarge?.copyWith(
                        color: t.colorScheme.primary,
                      ),
                    ),
                  ),
                  for (final d in porPeriodo[p]!)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        switch (d.situacao) {
                          SituacaoHistorico.aprovado ||
                          SituacaoHistorico.dispensado => Icons.check_circle,
                          SituacaoHistorico.reprovado => Icons.cancel,
                          SituacaoHistorico.cursando => Icons.timelapse,
                          SituacaoHistorico.trancado =>
                            Icons.pause_circle_outline,
                        },
                        color: switch (d.situacao) {
                          SituacaoHistorico.aprovado ||
                          SituacaoHistorico.dispensado => const Color(
                            0xFF2E7D32,
                          ),
                          SituacaoHistorico.reprovado => Colors.red,
                          SituacaoHistorico.cursando => const Color(0xFF0277BD),
                          SituacaoHistorico.trancado => Colors.grey,
                        },
                      ),
                      title: Text('${d.codigo} · ${d.nome}'),
                      trailing: Text(
                        d.nota == null
                            ? d.situacao.name
                            : d.nota!.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
