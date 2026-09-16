import 'package:flutter/material.dart';

/// Palette de couleurs premium FitForge AI.
///
/// Double palette : dark (par défaut, identité néon/glassmorphisme) et light
/// (soignée, même ADN de marque). Les couleurs **de marque** (primary, accent,
/// sémantiques, gradients hero) sont constantes dans les deux modes ; les
/// couleurs **neutres** (fonds, textes, bordures, verre) sont des getters
/// résolus selon [isDark].
///
/// [isDark] est positionné par le root de l'app (voir `theme_provider.dart`)
/// avant chaque rebuild global — ne pas le modifier ailleurs.
abstract final class AppColors {
  /// Mode courant. Piloté par le themeModeProvider au niveau du MaterialApp.
  static bool isDark = true;

  // ── Backgrounds ───────────────────────────────────────────────
  static Color get background =>
      isDark ? const Color(0xFF080C1A) : const Color(0xFFF4F5FB);
  static Color get surface =>
      isDark ? const Color(0xFF0F1428) : const Color(0xFFFFFFFF);
  static Color get card =>
      isDark ? const Color(0xFF141830) : const Color(0xFFFFFFFF);
  static Color get cardLight =>
      isDark ? const Color(0xFF1A2040) : const Color(0xFFEDEFF9);
  static Color get bottomBar =>
      isDark ? const Color(0xFF0C1020) : const Color(0xFFFFFFFF);

  // ── Primary (Violet électrique) ───────────────────────────────
  static const Color primary = Color(0xFF7C4DFF);
  static const Color primaryLight = Color(0xFFB388FF);
  static const Color primaryDark = Color(0xFF5A2ECC);
  // ── Accent (Cyan néon) ────────────────────────────────────────
  static const Color accent = Color(0xFF00E5FF);
  static const Color accentLight = Color(0xFF6EFFFF);
  static const Color accentDark = Color(0xFF00B8CC);

  /// Variante d'accent lisible sur fond clair (le cyan pur manque de
  /// contraste sur blanc) — à utiliser pour du texte/icône accentué.
  static Color get accentText =>
      isDark ? const Color(0xFF00E5FF) : const Color(0xFF0083A3);

  /// Variante de primary lisible selon le mode (texte/icônes).
  static Color get primaryText =>
      isDark ? const Color(0xFFB388FF) : const Color(0xFF5A2ECC);

  // ── Semantic ──────────────────────────────────────────────────
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFD740);
  static const Color error = Color(0xFFFF5252);
  static const Color info = Color(0xFF448AFF);

  /// Sémantiques lisibles en texte selon le mode.
  static Color get successText =>
      isDark ? const Color(0xFF00E676) : const Color(0xFF00893F);
  static Color get warningText =>
      isDark ? const Color(0xFFFFD740) : const Color(0xFF8A6D00);
  static Color get errorText =>
      isDark ? const Color(0xFFFF5252) : const Color(0xFFC62828);

  // ── Text ──────────────────────────────────────────────────────
  static Color get textPrimary =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF13182B);
  static Color get textSecondary =>
      isDark ? const Color(0xFFB0BEC5) : const Color(0xFF4C5568);
  static Color get textHint =>
      isDark ? const Color(0xFF607D8B) : const Color(0xFF7A8397);
  static Color get textDisabled =>
      isDark ? const Color(0xFF37474F) : const Color(0xFFB8BECF);

  /// Texte posé sur un gradient de marque (toujours sombre → blanc).
  static const Color onGradient = Color(0xFFFFFFFF);

  // ── Borders / Dividers ────────────────────────────────────────
  static Color get border =>
      isDark ? const Color(0xFF1E2640) : const Color(0xFFE1E4F0);
  static Color get divider =>
      isDark ? const Color(0xFF141C30) : const Color(0xFFECEEF6);

  // ── Glassmorphisme ────────────────────────────────────────────
  /// Fond translucide de champ/carte glass (5%).
  static Color get glassWhite =>
      isDark ? const Color(0x0DFFFFFF) : const Color(0x0D13182B);

  /// Translucide un peu plus opaque (10%).
  static Color get glassWhiteMid =>
      isDark ? const Color(0x1AFFFFFF) : const Color(0x1413182B);

  /// Border glass subtile.
  static Color get glassBorder =>
      isDark ? const Color(0x33FFFFFF) : const Color(0x2413182B);

  /// Glass surface (carte semi-transparente).
  static Color get glassSurface =>
      isDark ? const Color(0x1A1A2550) : const Color(0xB3FFFFFF);

  // ── Néon Glows ────────────────────────────────────────────────
  static const Color neonPrimary = Color(0x667C4DFF);
  static const Color neonAccent = Color(0x6600E5FF);
  static const Color neonSuccess = Color(0x6600E676);
  static const Color neonWarning = Color(0x66FFD740);
  static const Color neonError = Color(0x66FF5252);

  // ── Gradients de marque (identiques dans les deux modes) ──────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF9C27B0), Color(0xFF7C4DFF), Color(0xFF448AFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF6B11CB), Color(0xFF7C4DFF), Color(0xFF00B4D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFFD740)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00E5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Gradients neutres (dépendants du mode) ────────────────────
  static LinearGradient get cardGradient => LinearGradient(
    colors: isDark
        ? const [Color(0xFF1A2040), Color(0xFF0F1428)]
        : const [Color(0xFFFFFFFF), Color(0xFFF0F2FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get darkGradient => LinearGradient(
    colors: isDark
        ? const [Color(0xFF080C1A), Color(0xFF0D1030)]
        : const [Color(0xFFF4F5FB), Color(0xFFE9EBF8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Fond des écrans (dégradé très léger, remplace les gradients codés en dur
  /// dans chaque écran).
  static LinearGradient get screenGradient => LinearGradient(
    colors: isDark
        ? const [Color(0xFF080C1A), Color(0xFF13172C)]
        : const [Color(0xFFF4F5FB), Color(0xFFE9ECFA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static RadialGradient get authGradient => RadialGradient(
    colors: isDark
        ? const [Color(0xFF200B40), Color(0xFF080C1A)]
        : const [Color(0xFFE4DDFB), Color(0xFFF4F5FB)],
    center: const Alignment(0, -0.5),
    radius: 1.3,
  );

  // ── Macronutriments (nutrition) ───────────────────────────────
  // Une couleur par macro, constante dans les deux modes : elles servent de
  // code visuel partagé entre le bilan du jour, les cartes de repas et
  // l'aperçu temps réel de la recherche d'aliments.
  static const Color macroProtein = Color(0xFFFF6E6E); // rouge doux
  static const Color macroCarbs = Color(0xFFFFC53D); // ambre
  static const Color macroFat = Color(0xFF52B8FF); // bleu clair
  static const Color macroFiber = Color(0xFF7BD88F); // vert tendre

  // ── Intensité musculaire (body 2D/3D) ─────────────────────────
  static Color get muscleNone =>
      isDark ? const Color(0xFF1E2640) : const Color(0xFFD9DDEC);
  static const Color muscleLow = Color(0xFF2E9E4F);
  static const Color muscleMedium = Color(0xFFFF9E1B);
  static const Color muscleHigh = Color(0xFFFF5252);
  static const Color muscleMax = Color(0xFFD50000);

  // ── Helper methods ────────────────────────────────────────────

  /// Retourne une BoxShadow de glow pour un élément néon.
  static List<BoxShadow> neonGlow(
    Color color, {
    double blur = 20,
    double spread = 0,
  }) {
    final strength = isDark ? 1.0 : 0.55;
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.6 * strength),
        blurRadius: blur,
        spreadRadius: spread,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.3 * strength),
        blurRadius: blur * 2,
        spreadRadius: spread,
      ),
    ];
  }

  /// Ombre douce de carte (utile surtout en mode clair).
  static List<BoxShadow> get cardShadow => isDark
      ? const []
      : [
          BoxShadow(
            color: const Color(0xFF3A3F58).withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ];

  /// Retourne une BoxShadow de glow primaire standard.
  static List<BoxShadow> get primaryGlow => neonGlow(primary);

  /// Retourne une BoxShadow de glow accent standard.
  static List<BoxShadow> get accentGlow => neonGlow(accent);
}
