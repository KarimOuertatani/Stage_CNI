import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fitforge_app/features/auth/presentation/screens/login_screen.dart';
import 'package:fitforge_app/features/auth/presentation/screens/signup_screen.dart';
import 'package:fitforge_app/features/auth/presentation/widgets/auth_shell.dart';

/// Mise en page des écrans d'authentification.
///
/// Ces tests couvrent les deux défauts **structurels** corrigés en même temps
/// que le visuel — ceux qu'un simple coup d'œil sur un téléphone ne révèle pas :
///
/// 1. **la largeur n'était pas bornée.** Sur tablette ou en fenêtre desktop, les
///    champs s'étiraient sur toute la largeur : une ligne de saisie de 900 px,
///    que l'œil ne peut pas suivre ;
/// 2. **le clavier masquait le bas du formulaire.** Le contenu était dans un
///    `Center`, donc verticalement figé : les derniers champs passaient sous le
///    clavier sans qu'on puisse les atteindre.
void main() {
  setUpAll(() {
    Animate.restartOnHotReload = false;
  });

  Widget harness(Widget screen, {Size? size, double bottomInset = 0}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => screen),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(body: Text('LOGIN')),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const Scaffold(body: Text('SIGNUP')),
        ),
      ],
    );

    return ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(
          size: size ?? const Size(400, 800),
          viewInsets: EdgeInsets.only(bottom: bottomInset),
        ),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  /// Démonte l'arbre après avoir laissé filer les animations : les fonds animés
  /// bouclent, sans quoi le harnais échoue sur « A Timer is still pending ».
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
  }

  group('largeur bornée sur grand écran', () {
    for (final screen in [
      ('connexion', const LoginScreen()),
      ('inscription', const SignupScreen()),
    ]) {
      testWidgets('${screen.$1} : le formulaire ne s\'étire pas', (
        tester,
      ) async {
        // Une tablette en paysage : 1024 px de large.
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          harness(screen.$2, size: const Size(1024, 768)),
        );
        await tester.pump(const Duration(milliseconds: 400));

        // Le champ email sert de témoin : c'est lui qui s'étirait.
        final fieldWidth = tester
            .getSize(find.byType(TextFormField).first)
            .width;

        expect(
          fieldWidth,
          lessThanOrEqualTo(AuthShell.maxContentWidth),
          reason:
              'Un champ de ${fieldWidth.toStringAsFixed(0)} px est trop '
              'large pour être balayé du regard. Plafond attendu : '
              '${AuthShell.maxContentWidth} px.',
        );
        await disposeTree(tester);
      });
    }
  });

  group('le clavier ne masque pas le formulaire', () {
    for (final screen in [
      ('connexion', const LoginScreen()),
      ('inscription', const SignupScreen()),
    ]) {
      testWidgets('${screen.$1} : le contenu reste atteignable', (
        tester,
      ) async {
        // Petit téléphone + clavier ouvert : le cas le plus contraint.
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          harness(screen.$2, size: const Size(360, 640), bottomInset: 320),
        );
        await tester.pump(const Duration(milliseconds: 400));

        // Aucun débordement de mise en page, et le contenu défile : c'est ce
        // qui garantit qu'on peut atteindre le dernier champ.
        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsWidgets);

        final scrollable = find.byType(Scrollable).first;
        await tester.drag(scrollable, const Offset(0, -200));
        await tester.pump();

        expect(tester.takeException(), isNull);
        await disposeTree(tester);
      });
    }
  });

  testWidgets('« Mot de passe oublié ? » n\'est plus un bouton mort', (
    tester,
  ) async {
    // Vue haute : le lien doit être RÉELLEMENT visible pour que le tap
    // l'atteigne. Dans la vue de test par défaut (800×600), il tombe sous la
    // ligne de flottaison et le tap part dans le vide — sans que le test le
    // signale.
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(const LoginScreen()));
    await tester.pump(const Duration(milliseconds: 400));

    final link = find.text('Mot de passe oublié ?');
    await tester.ensureVisible(link);
    await tester.pump();
    await tester.tap(link);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Il ouvrait `onPressed: () {}` — rien du tout. Un utilisateur qui a
    // réellement oublié son mot de passe en concluait que l'app est cassée.
    // Il doit maintenant expliquer la marche à suivre.
    expect(find.textContaining('réinitialisation'), findsOneWidget);
    expect(find.textContaining('@'), findsWidgets);
    await disposeTree(tester);
  });
}
