import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/workout_model.dart';

/// Le vocabulaire visuel commun à tout ce qui affiche un exercice : carte de
/// liste, fiche de détail, feuille de séance, résultats de recherche.
///
/// Rassemblé ici parce que la couleur d'un niveau et l'image d'un exercice
/// étaient jusqu'ici redéfinies dans chaque écran — trois copies d'une même
/// table de correspondance, qui finissent toujours par se contredire.

/// Couleur associée à un niveau. Vert / ambre / rouge, comme partout ailleurs
/// dans l'app : ce sont les mêmes couleurs que la charge musculaire, et un
/// adhérent n'a pas à apprendre deux codes couleur.
Color levelColor(ExerciseLevel level) => switch (level) {
  ExerciseLevel.debutant => AppColors.success,
  ExerciseLevel.intermediaire => AppColors.warning,
  ExerciseLevel.avance => AppColors.error,
};

/// Icône du groupe musculaire (repli quand aucune image n'est disponible).
IconData muscleIcon(IconLabel label) => switch (label) {
  IconLabel.chest => Icons.accessibility_new_rounded,
  IconLabel.legs => Icons.directions_walk_rounded,
  IconLabel.back => Icons.back_hand_rounded,
  IconLabel.arms => Icons.fitness_center_rounded,
  IconLabel.shoulders => Icons.sports_gymnastics_rounded,
  IconLabel.abs => Icons.align_vertical_center_rounded,
};

/// « PECTORALIS MAJOR » → « Pectoralis Major » (libellés ExerciseDB en capitales).
String titleCase(String value) => value
    .toLowerCase()
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// Vignette d'un exercice : sa vraie photo, avec repli sur l'icône du groupe.
///
/// ## Pourquoi une image et plus une icône
///
/// Les 220 exercices du catalogue n'ont que six icônes de groupe à se
/// partager : une liste d'exercices de dos était donc une colonne de la même
/// icône répétée quinze fois, où seul le texte distinguait les lignes. On
/// reconnaît un mouvement à sa forme bien avant de lire son nom — surtout des
/// noms anglais. Les images existent déjà en base (`imageUrl360p`), elles
/// n'étaient simplement jamais affichées.
///
/// C'est la version **360p** qui est demandée ici, jamais la vidéo : une liste
/// qui défile ne doit pas déclencher quinze téléchargements de MP4.
class ExerciseThumbnail extends StatelessWidget {
  final WorkoutModel exercise;
  final double size;

  /// Pastille ▶ en surimpression quand une vidéo de démonstration existe.
  final bool showVideoBadge;

  const ExerciseThumbnail({
    super.key,
    required this.exercise,
    this.size = 64,
    this.showVideoBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final url = ApiConstants.proxiedMedia(exercise.thumbnailUrl);
    final radius = BorderRadius.circular(size * 0.26);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: radius,
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: url == null || url.isEmpty
                    ? _fallback()
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        // Une image qui manque ne doit pas laisser un trou :
                        // l'icône du groupe reste plus lisible qu'un carré vide.
                        errorBuilder: (_, _, _) => _fallback(),
                        loadingBuilder: (context, child, progress) =>
                            progress == null ? child : _fallback(),
                      ),
              ),
            ),
          ),
          if (showVideoBadge && exercise.hasVideo)
            Positioned(
              right: 3,
              bottom: 3,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: size * 0.22,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback() {
    return Container(
      alignment: Alignment.center,
      color: AppColors.surface,
      child: Icon(
        muscleIcon(exercise.icon),
        color: AppColors.accentText,
        size: size * 0.4,
      ),
    );
  }
}
