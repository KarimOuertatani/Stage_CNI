import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Avatar du coach IA.
///
/// **Pourquoi une icône et non une photo.** Les coachs humains de l'application
/// ont un visage ([CoachAvatar] affiche leur portrait). Donner un faux visage au
/// coach IA le ferait passer pour une personne — ce serait trompeur, et cela
/// brouillerait précisément la distinction que l'adhérent doit garder à
/// l'esprit : d'un côté des humains qui le suivent, de l'autre un assistant
/// disponible à toute heure.
///
/// Le dégradé accent et l'étincelle disent « fonctionnalité de l'app », pas
/// « personne ». La même forme sert dans l'en-tête du chat et sur la carte
/// d'entrée du hub : l'adhérent reconnaît immédiatement où il va.
class AiCoachAvatar extends StatelessWidget {
  final double size;

  /// Halo lumineux — réservé aux emplacements où l'avatar est le sujet
  /// principal (accueil du fil, carte d'entrée). Sur une petite taille dans une
  /// barre de titre, il ne ferait que baver.
  final bool glow;

  const AiCoachAvatar({super.key, this.size = 40, this.glow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.accentGradient,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.42),
                  blurRadius: size * 0.4,
                  offset: Offset(0, size * 0.1),
                ),
              ]
            : null,
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        // Proportionnel : la même classe sert de 34 px (barre de titre) à
        // 76 px (accueil du fil) sans réglage à la main.
        size: size * 0.52,
        color: AppColors.onGradient,
      ),
    );
  }
}
