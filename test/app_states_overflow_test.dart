import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitforge_app/core/widgets/app_states.dart';
import 'package:fitforge_app/core/widgets/neon_badge.dart' show ShimmerBox;

/// Non-régression du **débordement des états de chargement**.
///
/// Symptôme d'origine : des bandes jaunes et noires (« RenderFlex overflowed »)
/// apparaissaient au chargement et au rafraîchissement de plusieurs écrans.
/// `AppListSkeleton` était une `Column` de hauteurs fixes : demander 6 × 110 dp
/// dans une zone de 300 dp faisait déborder de plus de 450 dp.
///
/// Ces tests placent volontairement les widgets dans des espaces **trop
/// petits** : toute réapparition du problème les fait échouer, car Flutter
/// signale un débordement comme une exception de rendu.
void main() {
  /// Enveloppe le widget dans une zone de hauteur imposée.
  Widget boxed(Widget child, {required double height}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(height: height, width: 400, child: child),
        ),
      ),
    );
  }

  /// Laisse expirer les délais de `flutter_animate` puis démonte l'arbre.
  ///
  /// Ces widgets portent des animations à délai et à répétition infinie ; sans
  /// ce démontage, le harnais de test échoue sur « A Timer is still pending »
  /// — ce qui n'a rien à voir avec un débordement.
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
  }

  group('AppListSkeleton', () {
    testWidgets('ne déborde pas quand la place manque largement', (
      tester,
    ) async {
      // Le cas réel des exercices par zone : 6 × 110 + marges = 756 dp
      // demandés dans une zone bien plus courte.
      await tester.pumpWidget(
        boxed(
          const AppListSkeleton(itemCount: 6, itemHeight: 110),
          height: 300,
        ),
      );
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('ne déborde pas dans une zone minuscule', (tester) async {
      // Feuille modale écrasée par le clavier : même un seul élément ne tient
      // pas, il doit être rétréci plutôt que de déborder.
      await tester.pumpWidget(
        boxed(const AppListSkeleton(itemCount: 5, itemHeight: 150), height: 40),
      );
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('réduit le nombre d\'éléments à ce qui tient', (tester) async {
      // 300 dp disponibles, éléments de 100 dp + 16 d'espacement :
      // 2 éléments = 216 dp, 3 = 332 dp > 300. On en attend donc 2.
      await tester.pumpWidget(
        boxed(
          const AppListSkeleton(itemCount: 6, itemHeight: 100),
          height: 300,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ShimmerBox), findsNWidgets(2));
      await disposeTree(tester);
    });

    testWidgets('garde tous les éléments quand la hauteur est libre', (
      tester,
    ) async {
      // Dans une ListView, la hauteur est illimitée : aucune raison de
      // rogner le rendu demandé.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: const [AppListSkeleton(itemCount: 6, itemHeight: 110)],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ShimmerBox), findsNWidgets(6));
      await disposeTree(tester);
    });
  });

  group('AppEmptyState / AppErrorState', () {
    testWidgets('l\'état vide ne déborde pas dans une zone écrasée', (
      tester,
    ) async {
      // Conversation vide dont la zone se réduit à l'ouverture du clavier.
      await tester.pumpWidget(
        boxed(
          const AppEmptyState(
            icon: Icons.forum_outlined,
            title: 'Démarrez la conversation',
            message:
                'Envoyez un message, une photo ou un vocal pour lancer les échanges.',
          ),
          height: 120,
        ),
      );
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('l\'état erreur ne déborde pas dans une zone écrasée', (
      tester,
    ) async {
      await tester.pumpWidget(
        boxed(
          const AppErrorState(message: 'Impossible de charger les données.'),
          height: 120,
        ),
      );
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('reste rendable dans une hauteur libre (ListView)', (
      tester,
    ) async {
      // Plusieurs écrans placent déjà ces états dans une ListView. Il ne faut
      // surtout pas y imbriquer un second défilement sans hauteur : ce serait
      // une erreur « Vertical viewport was given unbounded height ».
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: const [
                AppErrorState(message: 'Erreur réseau'),
                AppEmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Rien ici',
                  message: 'Aucun élément à afficher pour le moment.',
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });
  });
}
