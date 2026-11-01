import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/academico/presentation/grade_page.dart';
import '../features/academico/presentation/historico_page.dart';
import '../features/comunidade/presentation/avaliacoes_page.dart';
import '../features/comunidade/presentation/foruns_page.dart';
import '../features/comunidade/presentation/orientacoes_page.dart';
import '../features/comunidade/presentation/publicacao_detalhe_page.dart';
import '../features/comunidade/presentation/publicacao_form_page.dart';
import '../features/conteudos/presentation/materiais_page.dart';
import '../features/divulgacao/presentation/anuncios_page.dart';
import '../features/divulgacao/presentation/eventos_page.dart';
import '../features/home/presentation/busca_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/home/presentation/notificacoes_page.dart';
import '../features/identidade/data/identidade_repository.dart';
import '../features/identidade/presentation/cadastro_page.dart';
import '../features/identidade/presentation/login_page.dart';
import '../features/identidade/presentation/perfil_page.dart';
import '../features/identidade/presentation/privacidade_page.dart';
import '../features/moderacao/presentation/admin_page.dart';
import '../models/permissoes.dart';
import '../models/publicacao.dart';
import '../models/usuario.dart';
import 'errors.dart';
import 'widgets/app_shell.dart';

const _rotasPublicas = {'/login', '/cadastro', '/privacidade'};

/// Área controlada pela matriz de permissões para cada prefixo de rota (RF13).
Area? areaDaRota(String local) {
  for (final (prefixo, area) in const [
    ('/foruns', Area.foruns),
    ('/anuncios', Area.anuncios),
    ('/eventos', Area.eventos),
    ('/materiais', Area.materiais),
    ('/grade', Area.grade),
    ('/avaliacoes', Area.avaliacoes),
    ('/orientacoes', Area.orientacoes),
  ]) {
    if (local == prefixo || local.startsWith('$prefixo/')) return area;
  }
  return null;
}

String inicioDoPerfil(Perfil p) =>
    p == Perfil.externo ? '/orientacoes' : '/home';

/// RNF07 — o router aplica as mesmas regras de acesso das Security Rules, para que o
/// usuário nunca chegue a uma tela que o servidor recusaria.
String? redirecionar(Sessao sessao, Uri uri) {
  final local = uri.path;
  switch (sessao) {
    case SessaoCarregando():
      return local == '/carregando'
          ? null
          : '/carregando?de=${Uri.encodeComponent(uri.toString())}';
    case SessaoDeslogada():
      return _rotasPublicas.contains(local) ? null : '/login';
    case SessaoIncompleta():
      return local == '/cadastro' || local == '/privacidade'
          ? null
          : '/cadastro';
    case SessaoAtiva(:final usuario):
      final inicio = inicioDoPerfil(usuario.perfil);
      if (local == '/carregando') {
        final destino = uri.queryParameters['de'];
        if (destino != null &&
            destino != '/' &&
            redirecionar(sessao, Uri.parse(destino)) == null) {
          return destino;
        }
        return inicio;
      }
      if (local == '/' || local == '/login' || local == '/cadastro') {
        return inicio;
      }
      if (local.startsWith('/admin')) {
        return usuario.perfil == Perfil.admin ? null : inicio;
      }
      if (usuario.perfil == Perfil.externo &&
          (local == '/home' || local == '/busca')) {
        return inicio;
      }
      final area = areaDaRota(local);
      if (area != null && !sessao.pode(area)) return inicio;
      final querPublicar = local.endsWith('/novo') || local.endsWith('/nova');
      if (area != null && querPublicar && !sessao.pode(area, Acao.publicar)) {
        return inicio;
      }
      return null;
  }
}

class _Refresh extends ChangeNotifier {
  void avisar() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _Refresh();
  ref.listen(sessaoProvider, (_, _) => refresh.avisar());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      LogService.rotaAtual = state.uri.path;
      return redirecionar(ref.read(sessaoProvider), state.uri);
    },
    errorBuilder: (context, state) => const PaginaNaoEncontrada(),
    routes: [
      GoRoute(path: '/carregando', builder: (_, _) => const TelaCarregando()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/cadastro', builder: (_, _) => const CadastroPage()),
      GoRoute(path: '/privacidade', builder: (_, _) => const PrivacidadePage()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(local: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomePage()),
          GoRoute(
            path: '/busca',
            builder: (_, s) =>
                BuscaPage(consultaInicial: s.uri.queryParameters['q'] ?? ''),
          ),
          GoRoute(
            path: '/notificacoes',
            builder: (_, _) => const NotificacoesPage(),
          ),
          GoRoute(path: '/perfil', builder: (_, _) => const PerfilPage()),
          GoRoute(
            path: '/foruns',
            builder: (_, _) => const ForunsPage(),
            routes: [
              GoRoute(
                path: 'topico/:id',
                builder: (_, s) =>
                    PublicacaoDetalhePage(id: s.pathParameters['id']!),
              ),
              GoRoute(
                path: ':forumId',
                builder: (_, s) =>
                    ForumPage(forumId: s.pathParameters['forumId']!),
              ),
              GoRoute(
                path: ':forumId/novo',
                builder: (_, s) => PublicacaoFormPage(
                  tipo: TipoPublicacao.topico,
                  categoriaInicial: s.pathParameters['forumId'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/anuncios',
            builder: (_, s) =>
                AnunciosPage(categoria: s.uri.queryParameters['categoria']),
            routes: [
              GoRoute(
                path: 'novo',
                builder: (_, _) =>
                    const PublicacaoFormPage(tipo: TipoPublicacao.anuncio),
              ),
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    PublicacaoDetalhePage(id: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/eventos',
            builder: (_, _) => const EventosPage(),
            routes: [
              GoRoute(
                path: 'novo',
                builder: (_, _) =>
                    const PublicacaoFormPage(tipo: TipoPublicacao.evento),
              ),
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    PublicacaoDetalhePage(id: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/materiais',
            builder: (_, s) =>
                MateriaisPage(cursoId: s.uri.queryParameters['curso']),
            routes: [
              GoRoute(
                path: 'novo',
                builder: (_, s) => NovoMaterialPage(
                  disciplinaId: s.uri.queryParameters['disciplina'],
                ),
              ),
              GoRoute(
                path: 'item/:id',
                builder: (_, s) =>
                    MaterialDetalhePage(id: s.pathParameters['id']!),
              ),
              GoRoute(
                path: 'disciplina/:codigo',
                builder: (_, s) => MateriaisDisciplinaPage(
                  codigo: s.pathParameters['codigo']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/grade',
            builder: (_, s) =>
                GradePage(cursoId: s.uri.queryParameters['curso']),
            routes: [
              GoRoute(
                path: 'historico',
                builder: (_, _) => const HistoricoPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/avaliacoes',
            builder: (_, s) =>
                AvaliacoesPage(aba: s.uri.queryParameters['aba']),
            routes: [
              GoRoute(
                path: ':tipo/:id',
                builder: (_, s) => AvaliacaoDetalhePage(
                  tipo: s.pathParameters['tipo']!,
                  id: s.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/orientacoes',
            builder: (_, _) => const OrientacoesPage(),
            routes: [
              GoRoute(
                path: 'nova',
                builder: (_, _) =>
                    const PublicacaoFormPage(tipo: TipoPublicacao.orientacao),
              ),
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    PublicacaoDetalhePage(id: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/admin',
            redirect: (_, s) =>
                s.uri.path == '/admin' ? '/admin/moderacao' : null,
            routes: [
              GoRoute(
                path: ':aba',
                builder: (_, s) => AdminPage(aba: s.pathParameters['aba']!),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class TelaCarregando extends StatelessWidget {
  const TelaCarregando({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class PaginaNaoEncontrada extends StatelessWidget {
  const PaginaNaoEncontrada({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.travel_explore, size: 64),
            const SizedBox(height: 16),
            Text(
              'Página não encontrada',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Voltar ao início'),
            ),
          ],
        ),
      ),
    );
  }
}
