import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// La **bande d'annonce** de la génération par l'IA, en tête de l'onglet
/// Programmes.
///
/// ## Ce n'est pas l'entrée de la fonctionnalité
///
/// C'est une nuance qui décide de tout son comportement. L'entrée permanente,
/// c'est [AiCreateButton], à côté de « Créer » — il est toujours là, il ne se
/// masque pas. Cette bande, elle, ne fait qu'**annoncer** : elle existe pour
/// que quelqu'un qui ne connaît pas encore la fonctionnalité la découvre, et
/// elle a le droit de disparaître une fois ce travail fait.
///
/// D'où la croix. Une annonce qu'on ne peut pas faire taire n'est plus une
/// annonce, c'est un encombrement — et elle occuperait le haut de l'écran à
/// chaque consultation de la liste, y compris pour quelqu'un qui a déjà généré
/// dix programmes.
///
/// Le masquage vaut pour **toute la session** et n'est écrit nulle part : la
/// bande revient au prochain démarrage de l'application. Un fichier de
/// préférences pour une bande d'annonce serait disproportionné, et « masquée
/// pour toujours » n'est pas ce qu'on demande en tapant sur une croix.
///
/// ## Ce que la bande annonce
///
/// Pas « l'IA », mais **ce que l'IA fait ici**. « Créé avec l'IA » ne dit rien
/// à personne ; « quelques questions et elle compose ton programme sur mesure »
/// dit exactement ce qu'on obtient.
///
/// ## Le mouvement
///
/// Un unique reflet qui balaie la carte toutes les quatre secondes. Long
/// intervalle, exprès : au-dessus d'une liste de programmes, un élément qui
/// s'agite en continu vole l'attention à ce que l'adhérent est venu consulter.
/// Il se rappelle à lui, il ne l'appelle pas.
class AiProgramCta extends StatelessWidget {
  /// Appelé au tap sur la croix. La bande disparaît pour la session.
  final VoidCallback onDismiss;

  const AiProgramCta({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          context.push('/programs/ai');
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(
                  alpha: AppColors.isDark ? 0.26 : 0.15,
                ),
                AppColors.accent.withValues(
                  alpha: AppColors.isDark ? 0.16 : 0.10,
                ),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.38),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.22),
                blurRadius: 26,
                spreadRadius: -6,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    children: [
                      const _AiOrb(),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Créer avec l\'IA',
                                    style: AppTextStyles.titleLarge.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.accentGradient,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    'NOUVEAU',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.onGradient,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            // Deux lignes au plus. La version longue en faisait
                            // quatre dans cette colonne étroite, et c'est elle
                            // qui donnait à la carte le tiers d'écran qu'elle
                            // n'a pas à occuper au-dessus d'une liste.
                            Text(
                              'Quelques questions, et l\'IA compose ton '
                              'programme sur mesure.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Wrap et non Row : un Row de puces à largeur fixe
                            // déborde dès que la colonne se resserre — écran
                            // étroit, ou texte agrandi par les réglages
                            // d'accessibilité. Wrap ne peut pas déborder.
                            //
                            // Deux puces et non trois : à trois, le repli était
                            // certain sur un téléphone étroit, et la carte
                            // reprenait la hauteur qu'on venait de lui retirer.
                            // « Modifiable » était la moins utile des trois —
                            // l'écran de détail le montre de lui-même.
                            const Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _CtaTag(
                                  icon: Icons.timer_outlined,
                                  label: '1 minute',
                                ),
                                _CtaTag(
                                  icon: Icons.tune_rounded,
                                  label: 'Sur mesure',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // La croix prend la place qu'occupait un chevron. Deux
                      // icônes sur le même bord d'une carte de 100 pixels de
                      // haut se lisent comme du bruit, et c'est la croix qui a
                      // une action propre : le reste de la carte est déjà
                      // tappable de bout en bout.
                      const SizedBox(width: 6),
                      _DismissButton(onTap: onDismiss),
                    ],
                  ),
                ),
                // Le reflet passe SOUS les pointeurs : il ne doit jamais
                // intercepter le tap qui ouvre l'assistant.
                Positioned.fill(
                  child: IgnorePointer(
                    child:
                        Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: 0.10),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.35, 0.5, 0.65],
                                ),
                              ),
                            )
                            .animate(
                              onPlay: (c) => c.repeat(period: 4200.ms),
                            )
                            .slideX(
                              begin: -1.4,
                              end: 1.4,
                              duration: 1500.ms,
                              curve: Curves.easeInOut,
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// **L'entrée permanente** de la génération par l'IA, à côté de « Créer ».
///
/// ## Son rôle par rapport à la bande
///
/// [AiProgramCta] annonce et disparaît ; ce bouton reste. C'est lui qu'on
/// cherche quand on sait déjà ce qu'on veut, et c'est le seul chemin qui
/// subsiste une fois la bande masquée. Il est donc placé là où l'œil va
/// naturellement chercher une création : dans l'en-tête de « Mes programmes »,
/// contre le « Créer » manuel.
///
/// ## Pourquoi il ne ressemble pas à « Créer »
///
/// Les deux boutons ne mènent pas au même effort. « Créer » ouvre un formulaire
/// vide qu'il faudra remplir séance par séance ; celui-ci produit un programme
/// entier. Leur donner la même apparence dirait qu'ils se valent. « Créer »
/// garde donc son contour discret, et celui-ci prend le dégradé de marque, son
/// halo et son étincelle — le même vocabulaire que l'orbe de la bande et que
/// l'écran de composition, pour qu'on reconnaisse la fonctionnalité partout où
/// elle apparaît.
///
/// ## Le mouvement, et sa retenue
///
/// Un reflet traverse le bouton toutes les six secondes, et le halo s'intensifie
/// sous le doigt. Rien ne pulse en continu : `PrimaryButton` a justement perdu
/// son halo clignotant parce qu'un élément qui s'agite sans raison vole
/// l'attention et fait tourner une animation pour rien. Ici le mouvement est
/// rare, ou bien il **répond** à l'appui.
class AiCreateButton extends StatefulWidget {
  final VoidCallback onTap;

  const AiCreateButton({super.key, required this.onTap});

  @override
  State<AiCreateButton> createState() => _AiCreateButtonState();
}

class _AiCreateButtonState extends State<AiCreateButton>
    with SingleTickerProviderStateMixin {
  /// Ne tourne que pendant l'appui. Entrée vive, retour plus posé — un retour
  /// aussi rapide que l'aller donne une impression de claquement.
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 240),
  );

  late final Animation<double> _amount = CurvedAnimation(
    parent: _press,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Créer un programme avec l\'IA',
      child: GestureDetector(
        onTapDown: (_) => _press.forward(),
        onTapUp: (_) => _press.reverse(),
        onTapCancel: () => _press.reverse(),
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _amount,
          builder: (context, child) {
            final t = _amount.value.clamp(0.0, 1.0);
            return Transform.scale(
              scale: 1 - 0.05 * t,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: 0.38 + t * 0.22,
                      ),
                      blurRadius: 14 + t * 8,
                      spreadRadius: -3,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 15,
                      color: AppColors.onGradient,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'IA',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.onGradient,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                // Le reflet ne doit jamais intercepter l'appui.
                Positioned.fill(
                  child: IgnorePointer(
                    child:
                        Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: 0.34),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.35, 0.5, 0.65],
                                ),
                              ),
                            )
                            .animate(onPlay: (c) => c.repeat(period: 6000.ms))
                            .slideX(
                              begin: -1.6,
                              end: 1.6,
                              duration: 1100.ms,
                              curve: Curves.easeInOut,
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La croix qui fait taire la bande.
///
/// Discrète à dessein : elle ne doit pas concurrencer l'action principale, qui
/// est d'ouvrir l'assistant. Mais sa zone tactile fait 34 pixels — bien plus
/// que l'icône de 15 — sinon on rate la croix et on ouvre l'assistant, ce qui
/// est le pire résultat possible pour quelqu'un qui voulait justement s'en
/// débarrasser.
class _DismissButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DismissButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Masquer cette annonce',
      child: GestureDetector(
        // opaque : le tap est consommé ici et ne remonte pas à l'InkWell de la
        // carte, sinon masquer ouvrirait l'assistant en même temps.
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.glassWhiteMid,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// L'orbe de la carte : un dégradé de marque, un halo, une étincelle qui
/// respire. Même vocabulaire visuel que l'écran de composition — l'adhérent
/// retrouve le même objet là où il a appuyé.
class _AiOrb extends StatelessWidget {
  const _AiOrb();

  @override
  Widget build(BuildContext context) {
    return Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.heroGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: -2,
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.onGradient,
            size: 22,
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.05, 1.05),
          duration: 1800.ms,
          curve: Curves.easeInOut,
        );
  }
}

class _CtaTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CtaTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.glassWhiteMid,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.accentText),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: AppColors.textSecondary,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
