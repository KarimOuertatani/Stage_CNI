import 'package:flutter/material.dart';

/// Aides à la mise en page adaptative.
///
/// L'app tourne sur des surfaces très différentes — petit téléphone (320 dp),
/// téléphone standard (360-430 dp), tablette, fenêtre Windows ou Chrome de
/// 1400 dp. Deux problèmes reviennent partout :
///
///  1. **Le débordement vertical** des grilles à ratio fixe
///     (`childAspectRatio`) : le ratio impose une hauteur qui ne tient pas
///     compte de la police système. Dès que l'utilisateur agrandit le texte
///     (réglage d'accessibilité), le contenu déborde.
///  2. **Les cartes démesurées** sur grand écran : une grille figée à
///     2 colonnes produit des tuiles gigantesques sur desktop.
///
/// [scaledExtent] et [gridColumns] répondent respectivement à l'un et l'autre.
abstract final class Responsive {
  // ── Points de rupture (en dp de largeur) ──────────────────────
  /// En dessous : petit téléphone (iPhone SE, Android d'entrée de gamme).
  static const double compact = 360;

  /// Au-dessus : tablette / desktop.
  static const double medium = 720;

  /// Au-dessus : grande fenêtre desktop.
  static const double expanded = 1100;

  /// Vrai sur les écrans étroits, où il faut resserrer les marges.
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  /// Vrai sur tablette et desktop.
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= medium;

  /// Hauteur d'une tuile de grille, **proportionnelle à la police système**.
  ///
  /// À utiliser avec `mainAxisExtent` plutôt qu'avec `childAspectRatio` :
  /// une hauteur en pixels qui grandit avec le texte ne peut pas déborder,
  /// alors qu'un ratio fixe déborde dès que la police augmente.
  ///
  /// [base] est la hauteur nécessaire à l'échelle de texte 1.0.
  /// [maxScale] plafonne l'agrandissement pour éviter des tuiles absurdes
  /// aux réglages d'accessibilité extrêmes (le contenu, lui, rétrécit grâce
  /// aux `FittedBox` des cartes).
  static double scaledExtent(
    BuildContext context,
    double base, {
    double maxScale = 1.5,
  }) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    return base * scale.clamp(1.0, maxScale);
  }

  /// Nombre de colonnes d'une grille de tuiles selon la largeur disponible.
  ///
  /// [compactCount] s'applique aux téléphones, puis on ajoute des colonnes
  /// sur tablette et desktop pour garder des tuiles de taille lisible.
  static int gridColumns(
    BuildContext context, {
    int compactCount = 2,
    int mediumCount = 3,
    int expandedCount = 4,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= expanded) return expandedCount;
    if (width >= medium) return mediumCount;
    return compactCount;
  }

  /// Marge horizontale d'écran : resserrée sur petit téléphone, et bornée
  /// sur grand écran pour que le contenu ne s'étale pas sur toute la largeur.
  static double screenPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compact) return 14;
    if (width >= expanded) return 32;
    return 20;
  }
}
