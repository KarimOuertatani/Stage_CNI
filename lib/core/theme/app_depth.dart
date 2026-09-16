import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Système d'ombres du projet — ce qui fait qu'une carte **flotte**.
///
/// ## Pourquoi un système et non des ombres à la main
///
/// Une seule ombre floue ne donne jamais l'impression d'élévation : elle salit.
/// Ce qui fait flotter un objet, dans le monde réel comme à l'écran, c'est la
/// **superposition de deux ombres de natures différentes** :
///
/// | Couche | Rôle | Caractéristique |
/// |---|---|---|
/// | **Ambiante** | Le contact avec le fond | courte, serrée, sous l'objet |
/// | **Portée** | La distance au fond | longue, large, très diffuse |
///
/// Sans l'ambiante, l'objet semble décollé et sale. Sans la portée, il semble
/// posé à plat. Les deux ensemble donnent une hauteur lisible.
///
/// Une **troisième couche colorée** est ajoutée sur les éléments accentués : la
/// lumière d'un objet coloré teinte ce qu'il y a autour. C'est ce qui distingue
/// un néon d'un rectangle gris.
///
/// ## Une seule définition, partout
///
/// Les valeurs vivent ici pour que toutes les cartes de l'application flottent
/// à la **même hauteur**. Des ombres réglées carte par carte produisent un
/// écran où chaque élément semble à une distance différente — l'effet exact
/// qu'on cherche à éviter.
abstract final class AppDepth {
  /// Élévation au repos : une carte posée sur l'écran, nettement détachée.
  static List<BoxShadow> get resting => [
    // Contact : courte et serrée.
    BoxShadow(
      color: Colors.black.withValues(alpha: AppColors.isDark ? 0.34 : 0.07),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
    // Distance : longue et diffuse.
    BoxShadow(
      color: Colors.black.withValues(alpha: AppColors.isDark ? 0.28 : 0.06),
      blurRadius: 24,
      offset: const Offset(0, 12),
      spreadRadius: -4,
    ),
  ];

  /// Élévation au survol / à l'inclinaison : la carte s'éloigne du fond.
  ///
  /// L'ombre s'allonge **et** se décale vers le bas : les deux ensemble lisent
  /// comme une prise de hauteur. Allonger sans décaler ne fait que flouter.
  static List<BoxShadow> get lifted => [
    BoxShadow(
      color: Colors.black.withValues(alpha: AppColors.isDark ? 0.40 : 0.10),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: AppColors.isDark ? 0.34 : 0.09),
      blurRadius: 38,
      offset: const Offset(0, 22),
      spreadRadius: -6,
    ),
  ];

  /// Élévation au repos, **teintée** par la couleur de l'élément.
  ///
  /// Réservée aux cartes accentuées. Un objet coloré éclaire ce qui l'entoure ;
  /// sans cette couche, une carte au dégradé violet projette une ombre grise et
  /// paraît collée.
  ///
  /// [strength] module l'intensité — utile pour l'animer pendant une
  /// interaction sans recalculer la liste.
  static List<BoxShadow> tinted(Color color, {double strength = 1}) => [
    ...resting,
    BoxShadow(
      color: color.withValues(alpha: 0.30 * strength),
      blurRadius: 30 * strength,
      offset: Offset(0, 12 * strength),
      spreadRadius: -8,
    ),
  ];

  /// Halo coloré marqué — pour un élément unique qui doit attirer l'œil
  /// (bannière d'accueil). Trop utilisé, il annule son propre effet.
  static List<BoxShadow> glow(Color color, {double strength = 1}) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: AppColors.isDark ? 0.32 : 0.08),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
    BoxShadow(
      color: color.withValues(alpha: 0.42 * strength),
      blurRadius: 44 * strength,
      offset: Offset(0, 18 * strength),
      spreadRadius: -6,
    ),
  ];

  /// Interpole entre deux élévations — pour animer sans à-coups.
  static List<BoxShadow> lerp(
    List<BoxShadow> from,
    List<BoxShadow> to,
    double t,
  ) {
    // Les deux listes ont la même longueur dans nos presets ; si ce n'était
    // pas le cas, on préfère rendre la cible plutôt que planter.
    if (from.length != to.length) return t < 0.5 ? from : to;
    return [
      for (var i = 0; i < from.length; i++) BoxShadow.lerp(from[i], to[i], t)!,
    ];
  }
}
