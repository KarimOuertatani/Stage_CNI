import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:fitforge_app/main.dart';
import 'package:fitforge_app/features/splash/presentation/screens/splash_screen.dart';

void main() {
  setUpAll(() {
    Animate.restartOnHotReload = false;

    // Sans plugin natif, la lecture du jeton ne répond JAMAIS : la session ne
    // serait donc jamais tranchée, et le splash tiendrait l'écran jusqu'à son
    // filet de sécurité. Un coffre vide simulé rejoue le cas réel « aucune
    // session enregistrée », qui est celui que ce test décrit.
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets(
    'FitForge démarre sur le splash, puis rend la main à la connexion',
    (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: MyApp()));
      await tester.pump();

      // Le premier écran n'est plus la connexion : le splash tient l'écran le
      // temps que la session soit tranchée, ce qui supprime le clignotement
      // « connexion → accueil » d'un utilisateur déjà connecté.
      expect(find.byType(SplashScreen), findsOneWidget);

      // Des temps distincts, et non un `pumpAndSettle` : l'écran de connexion
      // anime son logo en boucle, il ne se stabilise donc jamais.
      await tester.pump(
        const Duration(milliseconds: 500),
      ); // attente de décodage
      await tester.pump(const Duration(seconds: 4)); // intro
      await tester.pump(const Duration(milliseconds: 600)); // fondu de sortie
      await tester.pump(
        const Duration(milliseconds: 400),
      ); // transition de route

      // « FitForge » et non « FitForge AI » : la marque affichée est désormais
      // alignée sur le nom de l'app installée sur le téléphone (android:label,
      // CFBundleDisplayName). Deux noms pour un même produit, c'est un nom de
      // trop.
      expect(find.text('FitForge'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(MaterialApp), findsOneWidget);
    },
  );
}
