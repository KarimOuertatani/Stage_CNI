import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Bord à bord : l'app dessine SOUS les barres système. Sans ça, Android
  // réserve la hauteur de sa barre de navigation et la remplit d'un bandeau
  // plein — visible juste sous notre barre en verre, là où le contenu doit
  // continuer de défiler. La transparence seule ne suffit pas : il faut aussi
  // que la fenêtre s'étende dessous.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final mode = ref.watch(themeModeProvider);

    // La palette statique doit être résolue AVANT la construction du thème
    // et de l'arbre de widgets (voir AppColors.isDark).
    AppColors.isDark = mode == AppThemeMode.dark;

    // L'AppBarTheme ne couvre que les écrans qui ont une AppBar : ce réglage
    // global sert à tous les autres, dont le shell à onglets.
    SystemChrome.setSystemUIOverlayStyle(
      transparentSystemBars(AppColors.isDark),
    );

    return MaterialApp.router(
      // Le changement de key force la reconstruction complète de l'arbre :
      // indispensable car la palette est résolue statiquement au build.
      key: ValueKey(mode),
      title: 'FitForge AI',
      debugShowCheckedModeBanner: false,
      theme: mode == AppThemeMode.dark ? AppTheme.dark : AppTheme.light,
      routerConfig: router,
    );
  }
}
