import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fitforge_app/features/nutrition/presentation/screens/meals_screen.dart';
import 'package:fitforge_app/features/nutrition/presentation/widgets/add_meal_fab.dart';
import 'package:fitforge_app/shared/navigation/main_shell.dart';

/// Écran Nutrition : le **bouton d'ajout** et son menu déployable.
///
/// Ce test existe pour quatre raisons vécues :
/// 1. « je n'ai trouvé aucun bouton » — il vérifie qu'il est dans l'arbre ;
/// 2. « il est derrière la navbar » — il **mesure** qu'il la dégage ;
/// 3. « les boutons sont trop grands » — il **mesure** que le bouton au repos
///    tient en un seul cercle, que les options ne sont même pas montées, et que
///    les trois sont uniformes ;
/// 4. « le bouton d'ajout se répète » — il vérifie qu'une seule porte d'entrée
///    globale subsiste, l'AppBar et l'en-tête de liste n'en portant plus.
///
/// Le point 2 est facile à casser sans s'en rendre compte : le shell est en
/// `extendBody: true`, donc chaque onglet s'étend *sous* la barre de
/// navigation. Un élément flottant posé au ras du bas y disparaît, et rien
/// dans le code ne le signale.
///
/// ⚠️ **Non couvert ici** : la marge basse de la liste du journal, qui permet de
/// faire défiler la dernière carte au-dessus du bouton. Elle exige un état
/// chargé, donc un `nutritionProvider` simulé — à ajouter le jour où ce
/// harnais en disposera.
void main() {
  Widget harness() {
    final router = GoRouter(
      initialLocation: '/nutrition',
      routes: [
        GoRoute(
          path: '/nutrition',
          builder: (context, state) => const MealsScreen(),
        ),
        GoRoute(
          path: '/nutrition/photo',
          builder: (context, state) =>
              const Scaffold(body: Text('ECRAN ANALYSE PHOTO')),
        ),
        GoRoute(
          path: '/nutrition/voice',
          builder: (context, state) =>
              const Scaffold(body: Text('ECRAN AJOUT VOCAL')),
        ),
      ],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  /// Laisse expirer les délais d'animation puis démonte l'arbre : sans cela le
  /// harnais échoue sur « A Timer is still pending », ce qui n'a rien à voir
  /// avec ce qu'on vérifie ici.
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
  }

  /// Attend la fin d'une animation.
  ///
  /// `pumpAndSettle` est inutilisable ici : l'écran affiche des squelettes de
  /// chargement dont l'animation **boucle**, il n'atteindrait jamais le repos.
  /// On avance donc le temps explicitement, par **plusieurs images
  /// successives** — un unique grand `pump` laisserait au repos un contrôleur
  /// qui n'est armé qu'après la première image, et l'on mesurerait alors un
  /// widget replié sur son centre.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }
  }

  /// Ouvre le menu d'ajout et attend son déploiement complet.
  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add_rounded));
    await settle(tester);
  }

  /// Le cercle principal — `AddMealFab` occupe tout l'écran (il porte son
  /// propre voile), on ne peut donc pas le mesurer directement.
  Finder mainButton() => find
      .ancestor(
        of: find.byIcon(Icons.add_rounded),
        matching: find.byType(SizedBox),
      )
      .first;

  /// Les trois options du menu, dans l'ordre d'affichage.
  Finder optionLabels() => find.byWidgetPredicate(
    (w) => w is Text && const ['Photo', 'Vocal', 'Chercher'].contains(w.data),
  );

  /// Zone cliquable d'une option (c'est elle qu'on mesure, pas son libellé).
  Rect optionRect(WidgetTester tester, Widget label) => tester.getRect(
    find
        .ancestor(of: find.byWidget(label), matching: find.byType(InkWell))
        .first,
  );

  testWidgets('au repos, un seul bouton — les options sont cachées', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await settle(tester);

    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    // Le cœur de la correction : rien d'autre ne prend de place à l'écran.
    expect(find.text('Photo'), findsNothing);
    expect(find.text('Vocal'), findsNothing);
    expect(find.text('Chercher'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('au repos, le bouton ne dépasse pas un seul cercle', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await settle(tester);

    final size = tester.getSize(mainButton());

    // Sans les options déployées, le bouton doit occuper un cercle, pas la
    // hauteur d'une barre ou d'une pile.
    expect(
      size.height,
      closeTo(AddMealFab.collapsedSize, 1),
      reason: 'Le bouton au repos doit tenir en un cercle, mesuré : $size',
    );
    expect(size.width, closeTo(AddMealFab.collapsedSize, 1));
    await disposeTree(tester);
  });

  testWidgets('un appui déploie les trois options', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);
    await openMenu(tester);

    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Vocal'), findsOneWidget);
    expect(find.text('Chercher'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('les trois options ont exactement le même gabarit', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await settle(tester);
    await openMenu(tester);

    final sizes = tester
        .widgetList(optionLabels())
        .map((w) => optionRect(tester, w).size)
        .toList();

    expect(sizes, hasLength(3));
    expect(
      sizes.every((s) => s.height == sizes.first.height),
      isTrue,
      reason: 'Les trois options doivent être uniformes, mesuré : $sizes',
    );
    await disposeTree(tester);
  });

  testWidgets('un appui hors du menu le referme', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);
    await openMenu(tester);

    // Le voile couvre tout l'écran : un tap n'importe où suffit, sans avoir à
    // viser à nouveau le bouton.
    await tester.tapAt(const Offset(40, 200));
    await settle(tester);

    expect(find.text('Photo'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('le bouton d\'ajout n\'est pas dupliqué ailleurs', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await settle(tester);

    // L'AppBar ne porte plus de loupe, et l'en-tête de liste plus de lien
    // « Rechercher » : ils ouvraient déjà tous les deux la même chose.
    expect(find.text('Rechercher'), findsNothing);
    expect(find.byIcon(Icons.search_rounded), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('le bouton dégage la barre de navigation', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);

    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final clearance = screenHeight - tester.getRect(mainButton()).bottom;

    expect(
      clearance,
      greaterThanOrEqualTo(MainShell.bottomBarHeight),
      reason:
          'Le bouton doit laisser au moins ${MainShell.bottomBarHeight} px '
          'sous lui pour ne pas passer derrière la barre de navigation '
          '(dégagement mesuré : ${clearance.toStringAsFixed(1)} px).',
    );
    await disposeTree(tester);
  });

  testWidgets('un appui sur « Photo » ouvre /nutrition/photo', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);
    await openMenu(tester);

    await tester.tap(find.text('Photo'));
    await settle(tester);

    expect(find.text('ECRAN ANALYSE PHOTO'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('un appui sur « Vocal » ouvre /nutrition/voice', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);
    await openMenu(tester);

    await tester.tap(find.text('Vocal'));
    await settle(tester);

    expect(find.text('ECRAN AJOUT VOCAL'), findsOneWidget);
    await disposeTree(tester);
  });
}
