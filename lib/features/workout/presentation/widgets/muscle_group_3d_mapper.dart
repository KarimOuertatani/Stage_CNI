import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/muscle_catalog_3d.dart';
import '../../data/muscle_effort.dart';
import '../../data/workout_model.dart';

/// Pont entre les groupes musculaires de l'app (français) et les 466 muscles
/// du modèle `fitforge_body.glb`.
///
/// Le modèle est anatomique : chaque muscle est une entité distincte avec son
/// propre matériau, nommée en latin anglicisé (`long_head_of_biceps_brachii_r`).
/// Le catalogue [kMuscleCatalog3D] — généré depuis le GLB par
/// `scripts/gen_muscle_catalog_3d.py` — porte la traduction française, le
/// groupe de l'app et le caractère superficiel de chaque muscle.
///
/// Principe de coloration (inchangé depuis l'ancien modèle) : la couleur d'un
/// muscle vient de l'intensité d'effort de son groupe, sur une heatmap continue
/// repos → vert → orange → rouge.

/// Ordre de révélation des groupes (haut → bas), pour les libellés d'UI.
const List<String> revealOrder3D = kRevealOrder3D;

/// Résout un nom de noeud du GLB (`long_head_of_biceps_brachii_r`) vers sa
/// fiche anatomique. Retourne `null` si le noeud est inconnu du catalogue.
Muscle3D? muscle3DFor(String objectName) =>
    kMuscleCatalog3D[_baseName(objectName)];

/// Retire les suffixes d'export Blender : `.001` et le doublon `_2`.
String _stripExportSuffixes(String objectName) {
  var base = objectName;
  if (base.endsWith('.001')) base = base.substring(0, base.length - 4);
  if (base.endsWith('_2')) base = base.substring(0, base.length - 2);
  return base;
}

/// Nom de base d'un noeud : sans suffixe d'export ni marqueur de côté.
///
/// Deux conventions de côté coexistent dans le modèle : `_l` / `_r` pour les
/// muscles, `.l` / `.r` pour les aponévroses épicrâniennes.
String _baseName(String objectName) {
  final base = _stripExportSuffixes(objectName);
  return _sideSuffixes.contains(_lastTwo(base))
      ? base.substring(0, base.length - 2)
      : base;
}

const _sideSuffixes = {'_l', '_r', '.l', '.r'};

String _lastTwo(String value) =>
    value.length < 2 ? value : value.substring(value.length - 2);

/// Côté anatomique d'un muscle : `'gauche'`, `'droite'`, ou `null` s'il est
/// médian (diaphragme…).
String? side3DFor(String objectName) {
  final suffix = _lastTwo(_stripExportSuffixes(objectName));
  if (suffix == '_l' || suffix == '.l') return 'gauche';
  if (suffix == '_r' || suffix == '.r') return 'droite';
  return null;
}

/// Nom français lisible d'un muscle, côté compris (`Grand dorsal · droite`).
/// Retombe sur le nom brut du noeud si le muscle est absent du catalogue.
String frenchNameFor3D(String objectName) {
  final muscle = muscle3DFor(objectName);
  if (muscle == null) return objectName;
  final side = side3DFor(objectName);
  return side == null ? muscle.name : '${muscle.name} · $side';
}

/// Libellé de rattachement affiché sous le nom du muscle : le groupe de l'app
/// quand il existe, sinon la région anatomique fine.
String groupLabelFor3D(String objectName) {
  final muscle = muscle3DFor(objectName);
  if (muscle == null) return '—';
  return muscle.group ?? muscle.region;
}

/// Convertit une valeur d'intensité (0.0–1.0) en couleur par paliers
/// (utilisé pour les libellés / la légende).
Color colorFromIntensity(double intensity) {
  if (intensity == 0) return AppColors.muscleNone;
  if (intensity < 0.3) return AppColors.muscleLow;
  if (intensity < 0.6) return AppColors.muscleMedium;
  if (intensity < 0.85) return AppColors.muscleHigh;
  return AppColors.muscleMax;
}

/// Convertit une intensité (0.0–1.0) en couleur **continue** (heatmap) :
/// interpolation fluide repos → vert → orange → rouge → rouge profond.
/// Utilisé pour la coloration du modèle 3D (rendu plus organique que les
/// paliers).
Color colorFromIntensitySmooth(double intensity) {
  final t = intensity.clamp(0.0, 1.0);
  if (t == 0) return AppColors.muscleNone;
  if (t < 0.3) {
    return Color.lerp(AppColors.muscleNone, AppColors.muscleLow, t / 0.3)!;
  }
  if (t < 0.6) {
    return Color.lerp(
      AppColors.muscleLow,
      AppColors.muscleMedium,
      (t - 0.3) / 0.3,
    )!;
  }
  if (t < 0.85) {
    return Color.lerp(
      AppColors.muscleMedium,
      AppColors.muscleHigh,
      (t - 0.6) / 0.25,
    )!;
  }
  return Color.lerp(
    AppColors.muscleHigh,
    AppColors.muscleMax,
    (t - 0.85) / 0.15,
  )!;
}

/// Label textuel associé à une intensité.
String labelFromIntensity(double intensity) {
  if (intensity == 0) return 'Inactif';
  if (intensity < 0.3) return 'Léger';
  if (intensity < 0.6) return 'Moyen';
  if (intensity < 0.85) return 'Intense';
  return 'Maximum';
}

/// Couleur cible de **chaque muscle coloré**, à partir de la charge par muscle.
///
/// C'est ce qui rend la heatmap précise : un curl marteau n'allume que le
/// brachio-radial et un peu le biceps, au lieu de teinter tout le bras.
Map<String, Color> buildMuscle3DColorMap(MuscleEffort effort) => {
  for (final node in kHeatmapNodesTopDown)
    node: colorFromIntensitySmooth(effort.intensityOf(_baseName(node))),
};

/// Intensité d'un muscle 3D précis (0 s'il n'a pas été sollicité, ou s'il
/// n'appartient à aucun groupe entraîné).
double intensityForObject3D(String objectName, MuscleEffort effort) =>
    effort.intensityOf(_baseName(objectName));

/// Compare deux listes d'intensités par valeur (groupe + intensité).
bool sameIntensities(List<MuscleIntensity> a, List<MuscleIntensity> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].group != b[i].group || a[i].intensity != b[i].intensity) {
      return false;
    }
  }
  return true;
}

/// Ton de repos d'un muscle non sollicité.
///
/// Les muscles hors entraînement (visage, main, pied, viscères) reçoivent un
/// ton plus sourd pour que la silhouette entraînée ressorte, et chaque muscle
/// est décalé de quelques pour-cent de façon déterministe : sans cette
/// variation, 466 muscles à la couleur strictement identique se lisent comme
/// un mannequin monolithique au lieu d'une planche anatomique.
Color restingColorFor3D(String objectName) {
  final muscle = muscle3DFor(objectName);
  var color = AppColors.muscleNone;
  if (muscle?.group == null) {
    color = Color.lerp(color, AppColors.background, 0.45)!;
  }
  // Jitter déterministe dans ±5 % de luminosité, dérivé du nom du noeud.
  final hash = objectName.hashCode & 0xFF;
  final factor = 0.95 + (hash / 255.0) * 0.10;
  return Color.from(
    alpha: color.a,
    red: (color.r * factor).clamp(0.0, 1.0),
    green: (color.g * factor).clamp(0.0, 1.0),
    blue: (color.b * factor).clamp(0.0, 1.0),
  );
}

/// Convertit une [Color] Flutter en liste RGBA normalisée [0.0–1.0]
/// attendue par l'API de [Interactive3dController.setEntityMaterial].
List<double> colorToRgba(Color color) => [color.r, color.g, color.b, color.a];

/// Convertit une [Color] en émissif RGB (0.0–1.0+) pondéré par [factor]
/// (canal HDR de Filament — >1.0 = glow plus fort).
List<double> colorToEmissive(Color color, double factor) => [
  color.r * factor,
  color.g * factor,
  color.b * factor,
];
