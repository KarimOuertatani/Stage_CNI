import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'neon_badge.dart';

/// État vide designé — icône glow + titre + message + action optionnelle.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return _FittedState(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.08),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(icon, size: 40, color: AppColors.primaryText),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.05, 1.05),
                  duration: 1400.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTextStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              _StateActionButton(label: actionLabel!, onTap: onAction!),
            ],
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06),
      ),
    );
  }
}

/// État d'erreur designé — avec bouton "Réessayer".
class AppErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const AppErrorState({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _FittedState(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.25),
                ),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: AppColors.errorText,
              ),
            ).animate().shake(hz: 3, duration: 500.ms, rotation: 0.02),
            const SizedBox(height: 20),
            Text(
              'Oups, un problème est survenu',
              style: AppTextStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ??
                  'Impossible de charger les données. Vérifiez votre connexion.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              _StateActionButton(
                label: 'Réessayer',
                icon: Icons.refresh_rounded,
                onTap: onRetry!,
              ),
            ],
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06),
      ),
    );
  }
}

/// Centre son contenu tant qu'il tient, le rend défilable dès qu'il ne tient
/// plus — sans jamais déborder.
///
/// Les états vide et erreur sont hauts (icône + titre + message + bouton). Ils
/// passent très bien en plein écran, beaucoup moins quand la place se réduit :
/// clavier ouvert, feuille modale basse, mode paysage, petit téléphone. Le
/// débordement se voyait alors sous forme de bandeau rayé.
///
/// Quand la hauteur reçue est **libre** (contenu déjà placé dans une `ListView`
/// ou un `SingleChildScrollView`, ce que font plusieurs écrans), on ne remet
/// surtout pas un défilement par-dessus : ce serait un viewport imbriqué sans
/// hauteur, donc une erreur de rendu. On se contente alors de centrer.
class _FittedState extends StatelessWidget {
  final Widget child;
  const _FittedState({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxHeight.isFinite) {
          return Center(child: child);
        }
        return SingleChildScrollView(
          child: ConstrainedBox(
            // Au moins toute la hauteur offerte : le contenu reste centré
            // quand il y a de la place, et défile quand il n'y en a plus.
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

/// Skeleton de liste (shimmer) pour les états de chargement des listes.
///
/// **S'adapte à la place disponible.** [itemCount] et [itemHeight] décrivent le
/// rendu *souhaité* ; si la hauteur offerte est plus courte, le squelette
/// affiche moins d'éléments (et, en dernier recours, les rétrécit) plutôt que
/// de déborder.
///
/// > C'est un correctif, pas une coquetterie : une `Column` de hauteurs fixes
/// > peignait le bandeau rayé « RenderFlex overflowed » sur tous les écrans dont
/// > le squelette dépassait la hauteur utile — par exemple 6 × 110 + marges =
/// > 756 dp sur les exercices, ou la feuille de recherche d'aliments dont le
/// > clavier est ouvert d'office. Le débordement n'apparaissait donc que
/// > pendant le chargement et le rafraîchissement.
///
/// Quand la hauteur est **libre** (dans une `ListView`, un
/// `SingleChildScrollView`…), rien ne change : les [itemCount] éléments sont
/// rendus tels quels.
class AppListSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  /// Espace entre deux éléments (aucun après le dernier).
  static const double _gap = 16;

  const AppListSkeleton({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 96,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          var count = itemCount;
          var height = itemHeight;

          if (constraints.maxHeight.isFinite) {
            final available = constraints.maxHeight;

            // n éléments occupent n * hauteur + (n - 1) * espacement.
            final fits = ((available + _gap) / (itemHeight + _gap)).floor();
            count = math.max(1, math.min(itemCount, fits));

            // Même un seul élément peut ne pas tenir (feuille très basse) :
            // on le rétrécit pour que le total reste dans les clous.
            final needed = count * itemHeight + (count - 1) * _gap;
            if (needed > available) {
              height = math.max(0, (available - (count - 1) * _gap) / count);
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(count, (i) {
              return Padding(
                    padding: EdgeInsets.only(bottom: i == count - 1 ? 0 : _gap),
                    child: ShimmerBox(
                      width: double.infinity,
                      height: height,
                      borderRadius: 18,
                    ),
                  )
                  .animate()
                  .fadeIn(delay: (i * 80).ms, duration: 300.ms)
                  .slideY(begin: 0.04);
            }),
          );
        },
      ),
    );
  }
}

class _StateActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const _StateActionButton({
    required this.label,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
            color: AppColors.primary.withValues(alpha: 0.10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppColors.primaryText),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
