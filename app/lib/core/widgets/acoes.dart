import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/conteudos/data/upload_service.dart';
import '../../features/identidade/data/identidade_repository.dart';
import '../../features/moderacao/data/moderacao_repository.dart';
import '../../models/conteudo.dart';
import '../../models/publicacao.dart';
import '../errors.dart';

/// RF11 — campo de anexos reutilizado em fóruns, anúncios, eventos e materiais.
class CampoAnexos extends ConsumerStatefulWidget {
  const CampoAnexos({
    super.key,
    required this.area,
    required this.anexos,
    required this.onChanged,
    this.tiposPermitidos,
    this.maximo = 5,
    this.rotulo = 'Anexar arquivo',
  });

  final String area;
  final List<Anexo> anexos;
  final ValueChanged<List<Anexo>> onChanged;
  final Set<String>? tiposPermitidos;
  final int maximo;
  final String rotulo;

  @override
  ConsumerState<CampoAnexos> createState() => _CampoAnexosState();
}

class _CampoAnexosState extends ConsumerState<CampoAnexos> {
  double? _progresso;
  String? _erro;

  Future<void> _escolher() async {
    final usuario = ref.read(usuarioAtualProvider);
    if (usuario == null) return;
    setState(() => _erro = null);
    final arquivos = await FilePicker.pickFiles();
    if (arquivos.isEmpty) return;
    final arquivo = arquivos.first;
    try {
      final tamanho = await arquivo.xFile.length();
      // Valida antes de ler o arquivo inteiro na memória.
      UploadService.validar(
        arquivo.name,
        tamanho,
        tiposPermitidos: widget.tiposPermitidos,
      );
      final bytes = await arquivo.xFile.readAsBytes();
      setState(() => _progresso = 0);
      await for (final (p, anexo)
          in ref
              .read(uploadServiceProvider)
              .enviar(
                uid: usuario.uid,
                area: widget.area,
                nome: arquivo.name,
                bytes: bytes,
                tiposPermitidos: widget.tiposPermitidos,
              )) {
        if (!mounted) return;
        setState(() => _progresso = p);
        if (anexo != null) widget.onChanged([...widget.anexos, anexo]);
      }
    } catch (e, st) {
      if (e is! AppException) LogService.registrar(e, st, nivel: 'upload');
      setState(() => _erro = mensagemErro(e));
    } finally {
      if (mounted) setState(() => _progresso = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final formatos = FormatoArquivo.todos
        .where(
          (f) =>
              (widget.tiposPermitidos ?? {'pdf', 'imagem', 'video'}).contains(
                f.tipo,
              ) &&
              f.extensao != 'jpeg',
        )
        .map((f) => f.extensao.toUpperCase())
        .join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in widget.anexos)
              InputChip(
                avatar: Icon(_iconeAnexo(a.tipo), size: 18),
                label: Text(a.nome, overflow: TextOverflow.ellipsis),
                onDeleted: () =>
                    widget.onChanged([...widget.anexos]..remove(a)),
              ),
            if (widget.anexos.length < widget.maximo)
              OutlinedButton.icon(
                onPressed: _progresso == null ? _escolher : null,
                icon: const Icon(Icons.attach_file),
                label: Text(widget.rotulo),
              ),
          ],
        ),
        if (_progresso != null) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _progresso),
          const SizedBox(height: 4),
          Text(
            'Enviando... ${(_progresso! * 100).round()}%',
            style: t.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 6),
        Text(
          _erro ?? 'Formatos aceitos: $formatos • até 50 MB',
          style: t.textTheme.bodySmall?.copyWith(
            color: _erro != null
                ? t.colorScheme.error
                : t.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

IconData _iconeAnexo(String tipo) => switch (tipo) {
  'imagem' => Icons.image_outlined,
  'video' => Icons.movie_outlined,
  _ => Icons.picture_as_pdf_outlined,
};

/// Lista de anexos para download (RF11).
class ListaAnexos extends StatelessWidget {
  const ListaAnexos(this.anexos, {super.key});

  final List<Anexo> anexos;

  @override
  Widget build(BuildContext context) {
    final imagens = anexos.where((a) => a.tipo == 'imagem').toList();
    final outros = anexos.where((a) => a.tipo != 'imagem').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imagens.isNotEmpty)
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imagens.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => abrirUrl(context, imagens[i].url),
                  child: Image.network(
                    imagens[i].url,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 220,
                      color: Colors.black12,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (outros.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in outros)
                ActionChip(
                  avatar: Icon(_iconeAnexo(a.tipo), size: 18),
                  label: Text(a.nome),
                  onPressed: () => abrirUrl(context, a.url),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

Future<void> abrirUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      mostrarErro(
        context,
        const AppException('Não foi possível abrir o link.'),
      );
    }
  }
}

/// RF12 — botão de denúncia, com motivo obrigatório.
class BotaoDenunciar extends ConsumerWidget {
  const BotaoDenunciar({
    super.key,
    required this.alvoPath,
    required this.alvoTipo,
    required this.alvoTitulo,
    this.trecho,
    this.compacto = false,
  });

  final String alvoPath;
  final String alvoTipo;
  final String alvoTitulo;
  final String? trecho;
  final bool compacto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void abrir() => showDialog(
      context: context,
      builder: (_) => _DialogDenuncia(
        alvoPath: alvoPath,
        alvoTipo: alvoTipo,
        alvoTitulo: alvoTitulo,
        trecho: trecho,
      ),
    );
    return compacto
        ? IconButton(
            tooltip: 'Denunciar',
            icon: const Icon(Icons.flag_outlined, size: 20),
            onPressed: abrir,
          )
        : TextButton.icon(
            onPressed: abrir,
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('Denunciar'),
          );
  }
}

class _DialogDenuncia extends ConsumerStatefulWidget {
  const _DialogDenuncia({
    required this.alvoPath,
    required this.alvoTipo,
    required this.alvoTitulo,
    this.trecho,
  });

  final String alvoPath;
  final String alvoTipo;
  final String alvoTitulo;
  final String? trecho;

  @override
  ConsumerState<_DialogDenuncia> createState() => _DialogDenunciaState();
}

class _DialogDenunciaState extends ConsumerState<_DialogDenuncia> {
  MotivoDenuncia? _motivo;
  final _detalhes = TextEditingController();
  bool _enviando = false;
  String? _erro;

  Future<void> _enviar() async {
    final u = ref.read(usuarioAtualProvider)!;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await ref
          .read(moderacaoRepositoryProvider)
          .denunciar(
            uid: u.uid,
            alvoPath: widget.alvoPath,
            alvoTipo: widget.alvoTipo,
            alvoTitulo: widget.alvoTitulo,
            motivo: _motivo,
            detalhes: _detalhes.text,
            trecho: widget.trecho,
          );
      if (!mounted) return;
      Navigator.pop(context);
      mostrarSucesso(
        context,
        'Denúncia enviada. A moderação vai analisar o conteúdo.',
      );
    } catch (e) {
      setState(() => _erro = mensagemErro(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Denunciar conteúdo'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"${widget.alvoTitulo}"',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              const Text(
                'Qual o motivo?',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              RadioGroup<MotivoDenuncia>(
                groupValue: _motivo,
                onChanged: (v) => setState(() => _motivo = v),
                child: Column(
                  children: [
                    for (final m in MotivoDenuncia.values)
                      RadioListTile<MotivoDenuncia>(
                        value: m,
                        title: Text(m.label),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              TextField(
                controller: _detalhes,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Detalhes (opcional)',
                ),
              ),
              if (_erro != null)
                Text(
                  _erro!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _enviando || _motivo == null ? null : _enviar,
          child: _enviando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar denúncia'),
        ),
      ],
    );
  }
}
