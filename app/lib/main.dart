import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'core/errors.dart';
import 'core/firebase.dart';
import 'core/router.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LogService.instalar();
  await initializeDateFormatting('pt_BR');
  timeago.setLocaleMessages('pt_BR', timeago.PtBrMessages());
  await inicializarFirebase();
  // Expõe a árvore de acessibilidade no web (leitores de tela e testes automatizados).
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  runApp(const ProviderScope(child: HubUfjfApp()));
}

class HubUfjfApp extends ConsumerWidget {
  const HubUfjfApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'HUB-UFJF',
      debugShowCheckedModeBanner: false,
      theme: construirTema(Brightness.light),
      darkTheme: construirTema(Brightness.dark),
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
