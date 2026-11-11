import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/comum.dart';
import '../../../models/permissoes.dart';
import '../../../models/publicacao.dart';
import '../../../models/usuario.dart';
import '../../identidade/data/identidade_repository.dart';
import '../data/publicacoes_repository.dart';
import 'cartao_publicacao.dart';

/// RF14 — área de orientações: futuros alunos perguntam, estudantes respondem.
class OrientacoesPage extends ConsumerStatefulWidget {
  const OrientacoesPage({super.key});

  @override
  ConsumerState<OrientacoesPage> createState() => _OrientacoesPageState();
}

class _OrientacoesPageState extends ConsumerState<OrientacoesPage> {
  bool _somenteSemResposta = false;

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider) as SessaoAtiva;
    final externo = sessao.usuario.perfil == Perfil.externo;
    final perguntas = ref.watch(
      publicacoesProvider((
        tipo: TipoPublicacao.orientacao,
        status: StatusPublicacao.aprovado,
        forumId: null,
        categoria: null,
        ordenarPor: 'createdAt',
        decrescente: true,
      )),
    );
    final minhas = externo
        ? ref.watch(_minhasOrientacoesProvider(sessao.usuario.uid))
        : null;

    return Pagina(
      children: [
        CabecalhoPagina(
          titulo: externo
              ? 'Olá, ${sessao.usuario.primeiroNome}!'
              : 'Orientações',
          subtitulo: externo
              ? 'Tire dúvidas sobre cursos, vestibular e vida universitária com quem já estuda na UFJF'
              : 'Ajude futuros calouros com dúvidas sobre cursos e carreiras',
          icone: Icons.support_agent_outlined,
          acao: sessao.pode(Area.orientacoes, Acao.publicar)
              ? FilledButton.icon(
                  onPressed: () => context.go('/orientacoes/nova'),
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('Fazer uma pergunta'),
                )
              : null,
        ),
        if (minhas != null)
          AsyncView(
            value: minhas,
            data: (lista) => lista.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Minhas perguntas',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      for (final p in lista)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              p.status == StatusPublicacao.pendente
                                  ? Icons.hourglass_top
                                  : Icons.chat_outlined,
                            ),
                            title: Text(p.titulo),
                            subtitle: Text(switch (p.status) {
                              StatusPublicacao.pendente =>
                                'Aguardando aprovação da moderação',
                              StatusPublicacao.rejeitado =>
                                'Rejeitada${p.motivoModeracao != null ? ': ${p.motivoModeracao}' : ''}',
                              _ => '${p.respostasCount} respostas',
                            }),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go('/orientacoes/${p.id}'),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
          ),
        Row(
          children: [
            Text(
              'Perguntas da comunidade',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            FilterChip(
              label: const Text('Sem resposta'),
              selected: _somenteSemResposta,
              onSelected: (v) => setState(() => _somenteSemResposta = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AsyncView(
          value: perguntas,
          data: (lista) {
            final filtrada = _somenteSemResposta
                ? lista.where((p) => p.respostasCount == 0).toList()
                : lista;
            if (filtrada.isEmpty) {
              return const EstadoVazio(
                icone: Icons.question_answer_outlined,
                titulo: 'Nenhuma pergunta por aqui',
              );
            }
            return Column(
              children: [
                for (final p in filtrada)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CartaoPublicacao(p),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

final _minhasOrientacoesProvider = StreamProvider.autoDispose
    .family<List<Publicacao>, String>((ref, uid) {
      return ref
          .watch(publicacoesRepositoryProvider)
          .minhas(uid)
          .map(
            (l) => l
                .where(
                  (p) =>
                      p is Orientacao && p.status != StatusPublicacao.removido,
                )
                .toList(),
          );
    });
