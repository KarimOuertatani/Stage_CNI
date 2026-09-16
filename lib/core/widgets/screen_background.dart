import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'ambient_backdrop.dart';

/// Fond commun à tous les écrans principaux : le dégradé de base **plus** les
/// halos animés.
///
/// ## Pourquoi un widget et non un copier-coller
///
/// Six écrans portaient exactement la même ligne :
///
/// ```dart
/// Container(decoration: BoxDecoration(gradient: AppColors.screenGradient), …)
/// ```
///
/// Un dégradé fixe, identique partout, et **plat** : rien ne suggérait de
/// l'espace derrière les cartes. Ajouter les halos écran par écran aurait
/// multiplié les réglages — et la première divergence d'opacité aurait suffi à
/// faire sentir qu'on change d'écran, ce qui est exactement ce qu'on veut
/// éviter dans une navigation par onglets.
///
/// Un seul widget : les onglets partagent la **même** profondeur, et une
/// retouche se fait en un endroit.
///
/// ## L'intensité par défaut est basse, à dessein
///
/// 0,7 contre 1,0 sur l'accueil. Ces écrans sont **denses** — des listes, des
/// formulaires, des graphiques. Un fond aussi présent que sur l'accueil
/// passerait derrière du texte et nuirait à la lecture. Le fond doit se sentir,
/// pas se voir.
class ScreenBackground extends StatelessWidget {
  final Widget child;

  /// Intensité des halos. Voir [AmbientBackdrop.intensity].
  final double intensity;

  const ScreenBackground({
    super.key,
    required this.child,
    this.intensity = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppColors.screenGradient),
      child: Stack(
        children: [
          // Les halos sont un PLAN À PART, sous le contenu : c'est cette
          // dissociation qui fait lire les cartes comme flottant au-dessus de
          // quelque chose, plutôt que collées à un mur.
          Positioned.fill(child: AmbientBackdrop(intensity: intensity)),
          child,
        ],
      ),
    );
  }
}
