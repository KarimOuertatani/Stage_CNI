import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitforge_app/core/widgets/tilt_card.dart';

/// Tests de [TiltCard], le widget de relief partagé par tout l'accueil.
///
/// Trois propriétés comptent, et aucune n'est visuelle :
/// 1. **au repos, la carte ne doit pas être transformée** — sinon la mise en
///    page et le test de contact seraient décalés en permanence, sur tous les
///    écrans qui l'utilisent ;
/// 2. **le tap doit passer** malgré les couches ajoutées par-dessus l'enfant
///    (reflet, ombre) ;
/// 3. **l'inclinaison doit se couper** quand le système demande moins de
///    mouvement, sans rendre la carte inutilisable pour autant.
void main() {
  Widget harness({
    VoidCallback? onTap,
    bool disableAnimations = false,
    Size size = const Size(300, 140),
  }) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: TiltCard(
              onTap: onTap,
              child: const ColoredBox(
                color: Color(0xFF222222),
                child: Center(child: Text('CONTENU')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Porte l'appui jusqu'à l'inclinaison complète.
  ///
  /// ⚠️ **Deux `pump` sont nécessaires, pas un.** `onTapDown` n'est émis
  /// qu'après `kPressTimeout` (100 ms) : le premier `pump` fait expirer ce
  /// délai, ce qui démarre seulement l'animation. L'image dessinée à la fin de
  /// ce même `pump` la voit donc encore à zéro. Le second `pump` la laisse
  /// courir.
  Future<void> engage(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
  }

  /// Laisse le retour élastique se terminer.
  ///
  /// Même piège qu'à l'engagement : le `Ticker` du contrôleur ne démarre qu'à
  /// l'image suivante, si bien qu'un unique `pump`, même très long, ne fait pas
  /// avancer l'animation d'un iota.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  /// La transformation effectivement appliquée par la carte.
  Matrix4 appliedTransform(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find
          .ancestor(of: find.text('CONTENU'), matching: find.byType(Transform))
          .first,
    );
    return transform.transform;
  }

  testWidgets('au repos, la carte n\'est pas transformée', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    // Le point du test : une carte au repos doit se comporter EXACTEMENT comme
    // si le relief n'existait pas. Une transformation résiduelle décalerait la
    // mise en page et le test de contact sur tous les écrans concernés.
    expect(appliedTransform(tester), equals(Matrix4.identity()));
  });

  testWidgets('le contenu reste visible et à sa place', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('CONTENU'), findsOneWidget);
    final rect = tester.getRect(find.byType(TiltCard));
    expect(rect.width, 300);
    expect(rect.height, 140);
  });

  testWidgets('un appui déclenche bien le tap malgré le reflet par-dessus', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(harness(onTap: () => taps++));
    await tester.pump();

    // Le reflet et l'ombre sont empilés AU-DESSUS de l'enfant : sans
    // `IgnorePointer`, ils intercepteraient le tap.
    await tester.tap(find.byType(TiltCard));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('l\'appui incline la carte, le relâchement la remet à plat', (
    tester,
  ) async {
    await tester.pumpWidget(harness(onTap: () {}));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TiltCard)) + const Offset(80, 40),
    );
    await engage(tester);

    expect(
      appliedTransform(tester),
      isNot(equals(Matrix4.identity())),
      reason: 'La carte doit être inclinée pendant l\'appui.',
    );

    await gesture.up();
    await settle(tester);

    expect(
      appliedTransform(tester),
      equals(Matrix4.identity()),
      reason: 'La carte doit revenir exactement à plat.',
    );
  });

  testWidgets('la perspective est bien posée pendant l\'inclinaison', (
    tester,
  ) async {
    await tester.pumpWidget(harness(onTap: () {}));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TiltCard)) + const Offset(80, 40),
    );
    await engage(tester);

    // Sans l'entrée (3,2) de la matrice, les rotations ne produisent qu'un
    // cisaillement plat — l'effet 3D disparaît sans qu'aucun test visuel ne le
    // signale. C'est le seul indice vérifiable de la perspective.
    expect(appliedTransform(tester).entry(3, 2), isNot(0));

    await gesture.up();
    await settle(tester);
  });

  testWidgets('« réduire les animations » coupe l\'inclinaison, pas le tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      harness(onTap: () => taps++, disableAnimations: true),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TiltCard)) + const Offset(80, 40),
    );
    await engage(tester);

    expect(
      appliedTransform(tester),
      equals(Matrix4.identity()),
      reason: 'Aucune inclinaison quand le système demande moins de mouvement.',
    );

    await gesture.up();
    await tester.pump();

    // La carte doit rester parfaitement utilisable : on coupe l'effet, pas la
    // fonction.
    expect(taps, 1);
  });
}
