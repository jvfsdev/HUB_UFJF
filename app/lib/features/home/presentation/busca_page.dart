import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/widgets/comum.dart';
import '../../../models/conteudo.dart';
import '../../../models/permissoes.dart';
import '../../../models/publicacao.dart';
import '../../comunidade/data/publicacoes_repository.dart';
import '../../comunidade/presentation/cartao_publicacao.dart';
import '../../conteudos/data/conteudos_repository.dart';
import '../../conteudos/presentation/materiais_page.dart';
import '../../identidade/data/identidade_repository.dart';

/// RF15 — busca global sobre o índice de palavras-chave mantido pelas Cloud Functions.
class BuscaPage extends ConsumerStatefulWidget {
  const BuscaPage({super.key, this.consultaInicial = ''});

  final String consultaInicial;

  @override
  ConsumerState<BuscaPage> createState() => _BuscaPageState();
}

class _BuscaPageState extends ConsumerState<BuscaPage> {
  late final _controller = TextEditingController(text: widget.consultaInicial);
  Timer? _debounce;
  bool _buscando = false;
  String? _erro;
  List<Publicacao> _publicacoes = const [];
  List<MaterialEstudo> _materiais = const [];
  String _ultima = '';

  @override
  void initState() {
    super.initState();
    if (widget.consultaInicial.isNotEmpty) _buscar(widget.consultaInicial);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _aoDigitar(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _buscar(v));
  }

  Future<void> _buscar(String consulta) async {
    final sessao = ref.read(sessaoProvider);
    if (sessao is! SessaoAtiva) return;
    setState(() {
      _buscando = true;
      _erro = null;
      _ultima = consulta;
    });
    try {
      final tipos = TipoPublicacao.values.where((tp) => sessao.pode(tp.area));
      final (pubs, mats) = await (
        ref.read(publicacoesRepositoryProvider).buscar(consulta, tipos),
        sessao.pode(Area.materiais)
            ? ref.read(conteudosRepositoryProvider).buscar(consulta)
            : Future.value(const <MaterialEstudo>[]),
      ).wait;
      if (!mounted || consulta != _ultima) return;
      setState(() {
        _publicacoes = pubs;
        _materiais = mats;
      });
    } catch (e, st) {
      LogService.registrar(e, st, nivel: 'busca');
      if (mounted) setState(() => _erro = mensagemErro(e));
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final vazio = _ultima.trim().length < 3;
    final semResultado =
        !vazio && !_buscando && _publicacoes.isEmpty && _materiais.isEmpty;
    return Pagina(
      maxWidth: 860,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _aoDigitar,
          onSubmitted: _buscar,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Busque tópicos, anúncios, eventos e materiais (ex.: cálculo, república, circular)',
            suffixIcon: _buscando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 20),
        if (_erro != null)
          AvisoStatus(
            icone: Icons.error_outline,
            cor: t.colorScheme.error,
            texto: _erro!,
          ),
        if (vazio)
          const EstadoVazio(
            icone: Icons.manage_search,
            titulo: 'Digite ao menos 3 letras para buscar',
          )
        else if (semResultado)
          EstadoVazio(
            icone: Icons.search_off,
            titulo: 'Nada encontrado para "$_ultima"',
            mensagem: 'Tente outras palavras.',
          ),
        if (_materiais.isNotEmpty) ...[
          Text(
            'Materiais (${_materiais.length})',
            style: t.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final m in _materiais)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CartaoMaterial(m),
            ),
          const SizedBox(height: 16),
        ],
        if (_publicacoes.isNotEmpty) ...[
          Text(
            'Publicações (${_publicacoes.length})',
            style: t.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final p in _publicacoes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CartaoPublicacao(p, mostrarArea: true),
            ),
        ],
      ],
    );
  }
}
