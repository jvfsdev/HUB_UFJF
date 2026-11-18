import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/comum.dart';
import '../../identidade/data/identidade_repository.dart';
import '../../moderacao/data/moderacao_repository.dart';

/// Avisos de moderação, respostas e lembretes (RF07, RF12, RF14).
class NotificacoesPage extends ConsumerWidget {
  const NotificacoesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(usuarioAtualProvider)!;
    final repo = ref.read(moderacaoRepositoryProvider);
    final lista = ref.watch(notificacoesProvider);
    return Pagina(
      maxWidth: 760,
      children: [
        CabecalhoPagina(
          titulo: 'Notificações',
          icone: Icons.notifications_outlined,
          acao: (lista.value?.any((n) => !n.lida) ?? false)
              ? TextButton.icon(
                  onPressed: () => repo.marcarTodasLidas(u.uid, lista.value!),
                  icon: const Icon(Icons.done_all),
                  label: const Text('Marcar todas como lidas'),
                )
              : null,
        ),
        AsyncView(
          value: lista,
          data: (itens) => itens.isEmpty
              ? const EstadoVazio(
                  icone: Icons.notifications_none,
                  titulo: 'Nenhuma notificação por enquanto',
                )
              : Card(
                  child: Column(
                    children: [
                      for (final (i, n) in itens.indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          tileColor: n.lida
                              ? null
                              : Theme.of(context).colorScheme.primaryContainer
                                    .withValues(alpha: 0.25),
                          leading: Icon(n.icone),
                          title: Text(
                            n.texto,
                            style: TextStyle(
                              fontWeight: n.lida
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(tempoRelativo(n.createdAt)),
                          trailing: n.link != null
                              ? const Icon(Icons.chevron_right)
                              : null,
                          onTap: () {
                            if (!n.lida) repo.marcarLida(u.uid, n.id);
                            if (n.link != null) context.go(n.link!);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
