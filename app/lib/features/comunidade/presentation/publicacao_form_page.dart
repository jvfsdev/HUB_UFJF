import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors.dart';
import '../../../core/widgets/acoes.dart';
import '../../../core/widgets/comum.dart';
import '../../../models/categorias.dart';
import '../../../models/publicacao.dart';
import '../../../models/usuario.dart';
import '../../academico/data/academico_repository.dart';
import '../../identidade/data/identidade_repository.dart';
import '../data/comunidade_repository.dart';
import '../data/publicacoes_repository.dart';

/// Formulário único para tópicos (RF04), anúncios (RF06), eventos (RF09) e orientações (RF14).
class PublicacaoFormPage extends ConsumerStatefulWidget {
  const PublicacaoFormPage({
    super.key,
    required this.tipo,
    this.categoriaInicial,
  });

  final TipoPublicacao tipo;
  final String? categoriaInicial;

  @override
  ConsumerState<PublicacaoFormPage> createState() => _PublicacaoFormPageState();
}

class _PublicacaoFormPageState extends ConsumerState<PublicacaoFormPage> {
  final _titulo = TextEditingController();
  final _conteudo = TextEditingController();
  final _contato = TextEditingController();
  final _preco = TextEditingController();
  final _bairro = TextEditingController();
  final _local = TextEditingController();
  late String? _categoria = widget.categoriaInicial;
  DateTime? _data;
  TimeOfDay _hora = const TimeOfDay(hour: 19, minute: 0);
  List<Anexo> _anexos = const [];
  bool _enviando = false;
  List<String> _erros = const [];

  TipoPublicacao get tipo => widget.tipo;

  String get _titulo_ => switch (tipo) {
    TipoPublicacao.topico => 'Novo tópico',
    TipoPublicacao.anuncio => 'Novo anúncio',
    TipoPublicacao.evento => 'Divulgar evento ou projeto',
    TipoPublicacao.orientacao => 'Fazer uma pergunta',
  };

  String get _voltar => switch (tipo) {
    TipoPublicacao.topico =>
      widget.categoriaInicial == null
          ? '/foruns'
          : '/foruns/${widget.categoriaInicial}',
    TipoPublicacao.anuncio => '/anuncios',
    TipoPublicacao.evento => '/eventos',
    TipoPublicacao.orientacao => '/orientacoes',
  };

  /// Validação dos campos obrigatórios (fluxos alternativos de RF04, RF06 e RF09).
  List<String> _validar() {
    final erros = <String>[];
    if (_titulo.text.trim().length < 3) {
      erros.add('Informe um título com pelo menos 3 caracteres.');
    }
    if (_conteudo.text.trim().isEmpty) {
      erros.add(
        tipo == TipoPublicacao.orientacao
            ? 'Escreva sua dúvida.'
            : 'Preencha a descrição/conteúdo.',
      );
    }
    if (_conteudo.text.length > PublicacoesRepository.limiteConteudo) {
      erros.add('O conteúdo não pode exceder 5000 caracteres.');
    }
    if (tipo != TipoPublicacao.orientacao && _categoria == null) {
      erros.add('Selecione a categoria.');
    }
    if (tipo == TipoPublicacao.anuncio) {
      if (_contato.text.trim().length < 3) {
        erros.add(
          'Informe uma forma de contato (telefone, WhatsApp ou e-mail).',
        );
      }
      if (_preco.text.trim().isNotEmpty && _precoValor == null) {
        erros.add('Informe o preço apenas com números (ex.: 450,00).');
      }
    }
    if (tipo == TipoPublicacao.evento) {
      if (_data == null) {
        erros.add('Informe a data do evento.');
      } else if (_dataHora!.isBefore(DateTime.now())) {
        erros.add('A data do evento não pode ser anterior à data atual.');
      }
      if (_local.text.trim().isEmpty) erros.add('Informe o local do evento.');
    }
    return erros;
  }

  double? get _precoValor => double.tryParse(
    _preco.text.trim().replaceAll('.', '').replaceAll(',', '.'),
  );

  DateTime? get _dataHora => _data == null
      ? null
      : DateTime(
          _data!.year,
          _data!.month,
          _data!.day,
          _hora.hour,
          _hora.minute,
        );

  Future<void> _publicar(Usuario autor) async {
    final erros = _validar();
    setState(() => _erros = erros);
    if (erros.isNotEmpty) return;
    setState(() => _enviando = true);
    try {
      final extras = <String, dynamic>{
        if (tipo == TipoPublicacao.topico) 'forumId': _categoria,
        if (tipo == TipoPublicacao.anuncio) ...{
          'contato': _contato.text.trim(),
          'preco': _precoValor,
          'bairro': _bairro.text.trim().isEmpty ? null : _bairro.text.trim(),
        },
        if (tipo == TipoPublicacao.evento) ...{
          'dataEvento': _dataHora,
          'local': _local.text.trim(),
        },
        if (tipo == TipoPublicacao.orientacao) 'cursoInteresse': _categoria,
      };
      final id = await ref
          .read(publicacoesRepositoryProvider)
          .criar(
            tipo: tipo,
            autor: autor,
            titulo: _titulo.text,
            conteudo: _conteudo.text,
            categoria: tipo == TipoPublicacao.orientacao ? null : _categoria,
            anexos: _anexos,
            extras: extras,
          );
      if (!mounted) return;
      if (autor.perfil == Perfil.externo) {
        mostrarSucesso(
          context,
          'Enviado! Sua publicação será exibida após aprovação da moderação.',
        );
      } else {
        mostrarSucesso(context, 'Publicado com sucesso.');
      }
      final base = switch (tipo) {
        TipoPublicacao.topico => '/foruns/topico',
        TipoPublicacao.anuncio => '/anuncios',
        TipoPublicacao.evento => '/eventos',
        TipoPublicacao.orientacao => '/orientacoes',
      };
      context.go('$base/$id');
    } catch (e) {
      setState(() => _erros = [mensagemErro(e)]);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final autor = ref.watch(usuarioAtualProvider)!;

    return Pagina(
      maxWidth: 760,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(_voltar),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Cancelar'),
          ),
        ),
        CabecalhoPagina(titulo: _titulo_, icone: tipo.area.icon),
        if (autor.perfil == Perfil.externo)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: AvisoStatus(
              icone: Icons.info_outline,
              texto: 'Como membro da comunidade externa, sua publicação passa por aprovação da moderação antes de ficar visível.',
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _campoCategoria(),
                const SizedBox(height: 16),
                TextField(
                  controller: _titulo,
                  maxLength: 200,
                  buildCounter: contadorCaracteres,
                  decoration: InputDecoration(
                    labelText: tipo == TipoPublicacao.orientacao
                        ? 'Sua pergunta em uma frase'
                        : 'Título',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _conteudo,
                  minLines: 5,
                  maxLines: 14,
                  maxLength: PublicacoesRepository.limiteConteudo,
                  buildCounter: contadorCaracteres,
                  decoration: InputDecoration(
                    labelText: switch (tipo) {
                      TipoPublicacao.anuncio =>
                        'Descrição (estado, condições, o que está incluso)',
                      TipoPublicacao.evento => 'Descrição do evento ou projeto',
                      TipoPublicacao.orientacao =>
                        'Conte mais sobre sua dúvida',
                      _ => 'Conteúdo',
                    },
                    alignLabelWithHint: true,
                    helperText: 'Suporta formatação Markdown (**negrito**, listas, links).',
                  ),
                ),
                if (tipo == TipoPublicacao.anuncio) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contato,
                    decoration: const InputDecoration(
                      labelText: 'Contato',
                      hintText: '(32) 99999-0000 ou seu@email.com',
                      prefixIcon: Icon(Icons.contact_phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _preco,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Preço (opcional)',
                            prefixText: r'R$ ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _bairro,
                          decoration: const InputDecoration(
                            labelText: 'Bairro / local (opcional)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O HUB-UFJF não processa pagamentos: o preço é apenas informativo.',
                    style: t.textTheme.bodySmall,
                  ),
                ],
                if (tipo == TipoPublicacao.evento) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(
                            _data == null
                                ? 'Escolher data'
                                : dataFormatada(_data!),
                          ),
                          onPressed: () async {
                            final hoje = DateTime.now();
                            final d = await showDatePicker(
                              context: context,
                              firstDate: DateTime(hoje.year - 1),
                              lastDate: DateTime(hoje.year + 2),
                              initialDate: _data ?? hoje,
                            );
                            if (d != null) setState(() => _data = d);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.schedule),
                          label: Text(_hora.format(context)),
                          onPressed: () async {
                            final h = await showTimePicker(
                              context: context,
                              initialTime: _hora,
                            );
                            if (h != null) setState(() => _hora = h);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _local,
                    decoration: const InputDecoration(
                      labelText: 'Local',
                      hintText: 'Ex.: Anfiteatro do ICE, Campus UFJF',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                ],
                if (tipo != TipoPublicacao.orientacao) ...[
                  const SizedBox(height: 20),
                  Text(
                    tipo == TipoPublicacao.anuncio
                        ? 'Fotos e arquivos'
                        : 'Anexos',
                    style: t.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  CampoAnexos(
                    area: tipo.area.name,
                    anexos: _anexos,
                    onChanged: (a) => setState(() => _anexos = a),
                    rotulo: tipo == TipoPublicacao.anuncio
                        ? 'Adicionar foto'
                        : 'Anexar arquivo',
                  ),
                ],
                if (_erros.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in _erros)
                          Text(
                            '• $e',
                            style: TextStyle(
                              color: t.colorScheme.onErrorContainer,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _enviando ? null : () => _publicar(autor),
                  icon: _enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    autor.perfil == Perfil.externo
                        ? 'Enviar para aprovação'
                        : 'Publicar',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _campoCategoria() {
    final List<(String, String)> opcoes = switch (tipo) {
      TipoPublicacao.topico => [
        for (final f in ref.watch(forunsProvider).value ?? const <Forum>[])
          (f.id, f.nome),
      ],
      TipoPublicacao.anuncio => [
        for (final c in categoriasAnuncio) (c.id, c.label),
      ],
      TipoPublicacao.evento => [
        for (final c in categoriasEvento) (c.id, c.label),
      ],
      TipoPublicacao.orientacao => [
        for (final c in ref.watch(cursosProvider).value ?? const [])
          (c.id, c.rotulo),
      ],
    };
    final rotulo = switch (tipo) {
      TipoPublicacao.topico => 'Fórum',
      TipoPublicacao.orientacao => 'Curso de interesse (opcional)',
      _ => 'Categoria',
    };
    return DropdownButtonFormField<String>(
      initialValue: opcoes.any((o) => o.$1 == _categoria) ? _categoria : null,
      decoration: InputDecoration(labelText: rotulo),
      items: [
        for (final (id, label) in opcoes)
          DropdownMenuItem(value: id, child: Text(label)),
      ],
      onChanged: (v) => setState(() => _categoria = v),
    );
  }
}
