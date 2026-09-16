import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitforge_app/core/theme/app_colors.dart';
import 'package:fitforge_app/core/utils/responsive.dart';
import 'package:fitforge_app/features/home/presentation/widgets/quick_stats_card.dart';

/// Vérifie que les tuiles de statistiques ne débordent JAMAIS, quelles que
/// soient la largeur d'écran et la taille de police système.
///
/// Un `RenderFlex overflowed` fait échouer le test : ces cas sont donc une
/// protection contre la régression qui affectait la grille de l'accueil
/// (`childAspectRatio: 1.35` imposait ~112 px pour ~120 px de contenu).
void main() {
  /// Reproduit la grille de l'accueil pour une taille d'écran et une échelle
  /// de police données.
  Widget buildGrid({required double textScale}) {
    return MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GridView(
              padding: const EdgeInsets.all(20),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: Responsive.gridColumns(context),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: Responsive.scaledExtent(context, 126),
              ),
              children: const [
                QuickStatsCard(
                  title: 'Séances',
                  value: '12 / 5',
                  unit: 'semaine',
                  icon: Icons.fitness_center,
                  iconColor: Colors.purple,
                ),
                QuickStatsCard(
                  title: 'Calories',
                  value: '2450',
                  unit: 'kcal / 2400',
                  icon: Icons.local_fire_department,
                  iconColor: Colors.cyan,
                ),
                QuickStatsCard(
                  title: 'Objectif',
                  value: '72.5',
                  unit: 'kg visés',
                  icon: Icons.flag_outlined,
                  iconColor: Colors.blue,
                ),
                QuickStatsCard(
                  title: 'Sommeil',
                  value: '7.5',
                  unit: 'heures',
                  icon: Icons.bedtime,
                  iconColor: Colors.amber,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  setUp(() => AppColors.isDark = true);

  // Petit téléphone, téléphone standard, grand téléphone, tablette, desktop.
  const sizes = <String, Size>{
    'très petit téléphone (320x568)': Size(320, 568),
    'téléphone standard (360x800)': Size(360, 800),
    'grand téléphone (430x932)': Size(430, 932),
    'tablette (768x1024)': Size(768, 1024),
    'desktop (1440x900)': Size(1440, 900),
  };

  // 1.0 = normal, 1.3 = « grande police », 1.6 = accessibilité poussée.
  const textScales = <double>[1.0, 1.3, 1.6];

  for (final entry in sizes.entries) {
    for (final scale in textScales) {
      testWidgets(
        'Tuiles de stats sans débordement — ${entry.key}, police x$scale',
        (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(buildGrid(textScale: scale));
          await tester.pump(const Duration(seconds: 1)); // fin des animations

          // Un débordement de RenderFlex remonte ici sous forme d'exception.
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  group('Responsive', () {
    testWidgets('gridColumns s\'adapte à la largeur', (tester) async {
      Future<int> columnsFor(Size size) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        late int result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                result = Responsive.gridColumns(context);
                return const SizedBox();
              },
            ),
          ),
        );
        return result;
      }

      expect(await columnsFor(const Size(360, 800)), 2); // téléphone
      expect(await columnsFor(const Size(800, 1000)), 3); // tablette
      expect(await columnsFor(const Size(1440, 900)), 4); // desktop
    });

    testWidgets('scaledExtent grandit avec la police, mais reste borné', (
      tester,
    ) async {
      Future<double> extentFor(double scale) async {
        late double result;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  result = Responsive.scaledExtent(context, 100);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        return result;
      }

      expect(await extentFor(1.0), 100);
      expect(await extentFor(1.3), closeTo(130, 0.01));
      // Plafonné à maxScale = 1.5 : pas de tuile démesurée.
      expect(await extentFor(3.0), closeTo(150, 0.01));
    });
  });
}
