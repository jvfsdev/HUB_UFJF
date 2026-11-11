import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors.dart';
import '../../../core/widgets/acoes.dart';
import '../../../core/widgets/comum.dart';
import '../../../models/categorias.dart';
import '../../../models/permissoes.dart';
import '../../../models/publicacao.dart';
import '../../../models/usuario.dart';
import '../../academico/data/academico_repository.dart';
import '../../identidade/data/identidade_repository.dart';
import '../data/comunidade_repository.dart';
import '../data/publicacoes_repository.dart';

final _curtidoProvider = StreamProvider.autoDispose.family<bool, String>((
  ref,
  id,
) {
  final u = ref.watch(usuarioAtualProvider);
  if (u == null) return Stream.value(false);
  return ref.watch(publicacoesRepositoryProvider).curtido(id, u.uid);
});

/// Detalhe de tópico, anúncio, evento ou orientação, com respostas em tempo real (RF04, RF14).
class PublicacaoDetalhePage extends ConsumerStatefulWidget {
  const PublicacaoDetalhePage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<PublicacaoDetalhePage> createState() =>
      _PublicacaoDetalhePageState();
}

class _PublicacaoDetalhePageState extends ConsumerState<PublicacaoDetalhePage> {
  bool _registrado = false;

  @override
  Widget build(BuildContext context) {
    final valor = ref.watch(publicacaoProvider(widget.id));
    return AsyncView(
      value: valor,
      data: (p) {
        if (p == null || p.status == StatusPublicacao.removido) {
          return const EstadoVazio(
            icone: Icons.block,
            titulo: 'Conteúdo indisponível',
            mensagem: 'Esta publicação foi removida ou não existe mais.',
          );
        }
        final usuario = ref.watch(usuarioAtualProvider)!;
        if (!_registrado) {
          _registrado = true;
          ref
              .read(publicacoesRepositoryProvider)
              .registrarVisualizacao(p, usuario.uid);
        }
        return _Conteudo(p: p, usuario: usuario);
      },
    );
  }
}

class _Conteudo extends ConsumerWidget {
  const _Conteudo({required this.p, required this.usuario});

  final Publicacao p;
  final Usuario usuario;

  String get _voltar => switch (p) {
    Topico(:final forumId) => '/foruns/$forumId',
    Anuncio() => '/anuncios',
    Evento() => '/eventos',
    Orientacao() => '/orientacoes',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final sessao = ref.watch(sessaoProvider) as SessaoAtiva;
    final autor = p.autorId == usuario.uid;
    final curtido = ref.watch(_curtidoProvider(p.id)).value ?? false;
    final aceitaRespostas = p is Topico || p is Orientacao;

    return Pagina(
      maxWidth: 860,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(_voltar),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text('Voltar para ${p.tipo.area.label}'),
          ),
        ),
        if (p.status == StatusPublicacao.pendente)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: AvisoStatus(
              icone: Icons.hourglass_top,
              texto: 'Aguardando aprovação da moderação. Só você e os administradores podem ver esta publicação.',
            ),
          ),
        if (p.status == StatusPublicacao.rejeitado)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AvisoStatus(
              icone: Icons.cancel_outlined,
              cor: t.colorScheme.error,
              texto:
                  'Publicação rejeitada pela moderação${p.motivoModeracao != null ? ': ${p.motivoModeracao}' : '.'}',
            ),
          ),
        if (p.status == StatusPublicacao.arquivado)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: AvisoStatus(
              icone: Icons.inventory_2_outlined,
              cor: Colors.grey,
              texto: 'Este evento já aconteceu e foi arquivado.',
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AvatarUsuario(nome: p.autorNome, raio: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  p.autorNome,
                                  style: t.textTheme.titleSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              SeloPerfil(p.autorPerfil),
                            ],
                          ),
                          Text(
                            tempoRelativo(p.createdAt),
                            style: t.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (autor && p.status != StatusPublicacao.arquivado)
                      IconButton(
                        tooltip: 'Remover publicação',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remover(context, ref),
                      )
                    else if (!autor)
                      BotaoDenunciar(
                        alvoPath: p.path,
                        alvoTipo: p.tipo.name,
                        alvoTitulo: p.titulo,
                        trecho: p.conteudo,
                        compacto: true,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  p.titulo,
                  style: t.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoEspecifica(p),
                MarkdownBody(
                  data: p.conteudo,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(
                    t,
                  ).copyWith(p: t.textTheme.bodyLarge?.copyWith(height: 1.5)),
                  onTapLink: (_, href, _) =>
                      href == null ? null : abrirUrl(context, href),
                ),
                if (p.anexos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ListaAnexos(p.anexos),
                ],
                const SizedBox(height: 16),
                const Divider(),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: p.status != StatusPublicacao.aprovado
                          ? null
                          : () async {
                              try {
                                await ref
                                    .read(publicacoesRepositoryProvider)
                                    .alternarCurtida(
                                      p,
                                      usuario.uid,
                                      curtir: !curtido,
                                    );
                              } catch (e) {
                                if (context.mounted) mostrarErro(context, e);
                              }
                            },
                      icon: Icon(
                        curtido ? Icons.favorite : Icons.favorite_border,
                        color: curtido ? Colors.red : null,
                      ),
                      label: Text('${p.interacoes}'),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: t.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${p.views} visualizações',
                      style: t.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (p is Anuncio) _ContatoAnuncio(p as Anuncio),
        if (aceitaRespostas) ...[
          const SizedBox(height: 24),
          _Respostas(
            p: p,
            usuario: usuario,
            podeResponder: _podeResponder(sessao),
          ),
        ],
      ],
    );
  }

  bool _podeResponder(SessaoAtiva s) {
    if (p.status != StatusPublicacao.aprovado) return false;
    if (p is Orientacao) {
      return s.usuario.perfil == Perfil.estudante ||
          s.usuario.perfil == Perfil.admin;
    }
    return s.pode(Area.foruns, Acao.publicar);
  }

  Future<void> _remover(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover publicação?'),
        content: const Text('Ela deixará de aparecer para todos os usuários.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(publicacoesRepositoryProvider).remover(p.id);
      if (context.mounted) {
        mostrarSucesso(context, 'Publicação removida.');
        context.go(_voltar);
      }
    } catch (e) {
      if (context.mounted) mostrarErro(context, e);
    }
  }
}

class _InfoEspecifica extends ConsumerWidget {
  const _InfoEspecifica(this.p);

  final Publicacao p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    Widget linha(IconData i, String texto) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(i, size: 18, color: t.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: t.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    final filhos = switch (p) {
      Evento(:final dataEvento, :final local, :final categoria) => [
        TagChip(
          categoriaPorId(categoriasEvento, categoria).label,
          cor: categoriaPorId(categoriasEvento, categoria).cor,
        ),
        const SizedBox(height: 10),
        linha(Icons.schedule, dataHoraFormatada(dataEvento)),
        linha(Icons.place_outlined, local),
      ],
      Anuncio(:final preco, :final bairro, :final categoria) => [
        TagChip(
          categoriaPorId(categoriasAnuncio, categoria).label,
          cor: categoriaPorId(categoriasAnuncio, categoria).cor,
        ),
        const SizedBox(height: 10),
        if (preco != null) linha(Icons.payments_outlined, moeda(preco)),
        if (bairro != null) linha(Icons.place_outlined, bairro),
      ],
      Orientacao(:final cursoInteresse) when cursoInteresse != null => [
        linha(
          Icons.school_outlined,
          'Interesse: ${ref.watch(cursosProvider).value?.where((c) => c.id == cursoInteresse).firstOrNull?.nome ?? cursoInteresse}',
        ),
      ],
      Topico(:final forumId) => [
        if (ref
                .watch(forunsProvider)
                .value
                ?.where((f) => f.id == forumId)
                .firstOrNull
            case final f?)
          TagChip(f.nome, icone: f.iconData),
      ],
      _ => <Widget>[],
    };
    if (filhos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: filhos,
      ),
    );
  }
}

/// RF06 — o sistema apenas intermedeia o contato; não processa pagamentos.
class _ContatoAnuncio extends StatelessWidget {
  const _ContatoAnuncio(this.a);

  final Anuncio a;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ehEmail = a.contato.contains('@');
    final digitos = a.contato.replaceAll(RegExp(r'\D'), '');
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        color: t.colorScheme.primaryContainer.withValues(alpha: 0.4),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contato do anunciante',
                style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(a.contato, style: t.textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!ehEmail && digitos.length >= 10)
                    FilledButton.icon(
                      onPressed: () =>
                          abrirUrl(context, 'https://wa.me/55$digitos'),
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('WhatsApp'),
                    ),
                  if (ehEmail)
                    FilledButton.icon(
                      onPressed: () => abrirUrl(context, 'mailto:${a.contato}'),
                      icon: const Icon(Icons.mail_outline),
                      label: const Text('Enviar e-mail'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: a.contato));
                      mostrarSucesso(context, 'Contato copiado.');
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'O HUB-UFJF apenas aproxima interessados e não intermedeia pagamentos. Combine diretamente com o anunciante '
                'e desconfie de pedidos de pagamento antecipado.',
                style: t.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Respostas extends ConsumerStatefulWidget {
  const _Respostas({
    required this.p,
    required this.usuario,
    required this.podeResponder,
  });

  final Publicacao p;
  final Usuario usuario;
  final bool podeResponder;

  @override
  ConsumerState<_Respostas> createState() => _RespostasState();
}

class _RespostasState extends ConsumerState<_Respostas> {
  final _texto = TextEditingController();
  bool _enviando = false;

  Future<void> _responder() async {
    setState(() => _enviando = true);
    try {
      final cursos = ref.read(cursosProvider).value ?? const [];
      final curso = cursos
          .where((c) => c.id == widget.usuario.cursoId)
          .firstOrNull
          ?.nome;
      await ref
          .read(publicacoesRepositoryProvider)
          .responder(
            widget.p.id,
            widget.usuario,
            _texto.text,
            cursoAutor: curso,
          );
      _texto.clear();
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final orientacao = widget.p is Orientacao;
    final respostas = ref.watch(respostasProvider(widget.p.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${respostas.value?.length ?? widget.p.respostasCount} ${orientacao ? 'orientações de estudantes' : 'respostas'}',
          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        AsyncView(
          value: respostas,
          data: (lista) => lista.isEmpty
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      orientacao
                          ? 'Ainda sem respostas. Os estudantes cadastrados foram avisados sobre sua dúvida.'
                          : 'Nenhuma resposta ainda.',
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final r in lista)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    AvatarUsuario(nome: r.autorNome, raio: 14),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        r.autorNome,
                                        style: t.textTheme.labelLarge,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    SeloPerfil(r.autorPerfil),
                                    if (r.cursoAutor != null) ...[
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          r.cursoAutor!,
                                          style: t.textTheme.bodySmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    Text(
                                      tempoRelativo(r.createdAt),
                                      style: t.textTheme.bodySmall,
                                    ),
                                    if (r.autorId == widget.usuario.uid)
                                      IconButton(
                                        tooltip: 'Remover resposta',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                        ),
                                        onPressed: () async {
                                          try {
                                            await ref
                                                .read(
                                                  publicacoesRepositoryProvider,
                                                )
                                                .removerResposta(r.path);
                                          } catch (e) {
                                            if (context.mounted) {
                                              mostrarErro(context, e);
                                            }
                                          }
                                        },
                                      )
                                    else
                                      BotaoDenunciar(
                                        alvoPath: r.path,
                                        alvoTipo: 'resposta',
                                        alvoTitulo:
                                            'Resposta em "${widget.p.titulo}"',
                                        trecho: r.conteudo,
                                        compacto: true,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                MarkdownBody(
                                  data: r.conteudo,
                                  selectable: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        if (widget.podeResponder) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _texto,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: PublicacoesRepository.limiteConteudo,
                    buildCounter: contadorCaracteres,
                    decoration: InputDecoration(
                      hintText: orientacao
                          ? 'Compartilhe sua experiência com o futuro calouro...'
                          : 'Escreva sua resposta...',
                      border: InputBorder.none,
                      filled: false,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _enviando ? null : _responder,
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Responder'),
                  ),
                ],
              ),
            ),
          ),
        ] else if (widget.p is Orientacao &&
            widget.usuario.perfil == Perfil.externo)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Você será notificado quando um estudante responder.'),
          ),
      ],
    );
  }
}
