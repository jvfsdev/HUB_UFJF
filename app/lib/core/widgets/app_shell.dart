import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/identidade/data/identidade_repository.dart';
import '../../features/moderacao/data/moderacao_repository.dart';
import '../../models/permissoes.dart';
import '../../models/usuario.dart';
import '../theme.dart';
import 'comum.dart';

class _Destino {
  const _Destino(
    this.rota,
    this.label,
    this.icone,
    this.iconeAtivo, {
    this.area,
  });
  final String rota;
  final String label;
  final IconData icone;
  final IconData iconeAtivo;
  final Area? area;
}

const _destinos = [
  _Destino('/home', 'Início', Icons.home_outlined, Icons.home),
  _Destino(
    '/foruns',
    'Fóruns',
    Icons.forum_outlined,
    Icons.forum,
    area: Area.foruns,
  ),
  _Destino(
    '/materiais',
    'Materiais',
    Icons.menu_book_outlined,
    Icons.menu_book,
    area: Area.materiais,
  ),
  _Destino(
    '/grade',
    'Grade',
    Icons.account_tree_outlined,
    Icons.account_tree,
    area: Area.grade,
  ),
  _Destino(
    '/avaliacoes',
    'Avaliações',
    Icons.star_outline,
    Icons.star,
    area: Area.avaliacoes,
  ),
  _Destino(
    '/anuncios',
    'Anúncios',
    Icons.storefront_outlined,
    Icons.storefront,
    area: Area.anuncios,
  ),
  _Destino(
    '/eventos',
    'Eventos',
    Icons.event_outlined,
    Icons.event,
    area: Area.eventos,
  ),
  _Destino(
    '/orientacoes',
    'Orientações',
    Icons.support_agent_outlined,
    Icons.support_agent,
    area: Area.orientacoes,
  ),
  _Destino('/admin/moderacao', 'Admin', Icons.shield_outlined, Icons.shield),
];

/// Estrutura de navegação responsiva (RNF13): NavigationRail no desktop e Drawer no mobile.
/// Os destinos exibidos seguem as permissões do perfil em tempo real (RF13).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.local, required this.child});

  final String local;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider);
    if (sessao is! SessaoAtiva) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final usuario = sessao.usuario;

    final destinos = _destinos.where((d) {
      if (d.rota == '/admin/moderacao') return usuario.perfil == Perfil.admin;
      if (d.rota == '/home') return usuario.perfil != Perfil.externo;
      return d.area == null || sessao.pode(d.area!);
    }).toList();

    final selecionado = destinos.indexWhere(
      (d) =>
          local == d.rota ||
          local.startsWith('${d.rota.split('/').take(2).join('/')}/') ||
          local == d.rota.split('/').take(2).join('/'),
    );

    final mobile = context.isMobile;
    final appBar = AppBar(
      titleSpacing: mobile ? 0 : 24,
      title: InkWell(
        onTap: () => context.go(destinos.first.rota),
        child: const _Marca(),
      ),
      actions: [
        if (usuario.perfil != Perfil.externo)
          IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/busca'),
          ),
        const _SinoNotificacoes(),
        _MenuUsuario(usuario: usuario),
        const SizedBox(width: 8),
      ],
    );

    if (mobile) {
      return Scaffold(
        appBar: appBar,
        drawer: NavigationDrawer(
          selectedIndex: selecionado < 0 ? null : selecionado,
          onDestinationSelected: (i) {
            Navigator.pop(context);
            context.go(destinos[i].rota);
          },
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(28, 20, 16, 16),
              child: _Marca(),
            ),
            for (final d in destinos)
              NavigationDrawerDestination(
                icon: Icon(d.icone),
                selectedIcon: Icon(d.iconeAtivo),
                label: Text(d.label),
              ),
          ],
        ),
        body: child,
      );
    }

    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          NavigationRail(
            extended: context.isDesktop,
            minExtendedWidth: 210,
            selectedIndex: selecionado < 0 ? null : selecionado,
            labelType: context.isDesktop
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            onDestinationSelected: (i) => context.go(destinos[i].rota),
            destinations: [
              for (final d in destinos)
                NavigationRailDestination(
                  icon: Icon(d.icone),
                  selectedIcon: Icon(d.iconeAtivo),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: azulUfjf,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'HUB',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'UFJF',
          style: t.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: azulUfjf,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _SinoNotificacoes extends ConsumerWidget {
  const _SinoNotificacoes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final naoLidas =
        ref.watch(notificacoesProvider).value?.where((n) => !n.lida).length ??
        0;
    return IconButton(
      tooltip: 'Notificações',
      onPressed: () => context.go('/notificacoes'),
      icon: Badge(
        isLabelVisible: naoLidas > 0,
        label: Text('$naoLidas'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _MenuUsuario extends ConsumerWidget {
  const _MenuUsuario({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Minha conta',
      offset: const Offset(0, 48),
      onSelected: (v) async {
        if (v == 'perfil') context.go('/perfil');
        if (v == 'privacidade') context.go('/privacidade');
        if (v == 'sair') await ref.read(identidadeRepositoryProvider).sair();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                usuario.nome,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              Text(usuario.email, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              SeloPerfil(usuario.perfil),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'perfil',
          child: ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Meu perfil'),
          ),
        ),
        const PopupMenuItem(
          value: 'privacidade',
          child: ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Privacidade'),
          ),
        ),
        const PopupMenuItem(
          value: 'sair',
          child: ListTile(leading: Icon(Icons.logout), title: Text('Sair')),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AvatarUsuario(nome: usuario.nome, raio: 17),
      ),
    );
  }
}
