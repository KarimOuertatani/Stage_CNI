import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Bouton d'ajout de repas : **un seul cercle au repos**, trois options au
/// déploiement.
///
/// ## Pourquoi un menu et non trois boutons visibles
///
/// Les trois façons d'enregistrer un repas — photographier, dicter, chercher —
/// sont de vraies alternatives, mais on n'en déclenche qu'une, quelques fois
/// par jour. Les afficher en permanence fait payer à l'écran une surface
/// permanente pour un usage ponctuel : la barre précédente masquait la dernière
/// carte du journal en continu.
///
/// Un bouton unique ne coûte cette surface **qu'au moment où on en a besoin**,
/// et l'occultation devient alors attendue — c'est le principe d'un menu.
///
/// ## Ce que ça coûte, et comment c'est compensé
///
/// Des actions cachées demandent **un tap de plus** et ne se découvrent pas au
/// premier coup d'œil. Deux réponses :
/// - **les libellés sont affichés** au déploiement, jamais des icônes seules ;
/// - le `+` **pivote en `×`**, ce qui dit sans mot que le bouton est un menu et
///   que l'état est refermable.
///
/// ## Pourquoi une pile verticale et non un arc
///
/// Un déploiement radial est plus spectaculaire, mais les positions deviennent
/// imprévisibles d'une option à l'autre, les cibles plus difficiles à viser au
/// pouce, et il n'existe aucun endroit naturel pour poser les libellés. Trois
/// cercles empilés, chacun avec son étiquette à gauche, produisent le même
/// effet en restant prévisibles.
///
/// ## L'ordre n'est pas arbitraire
///
/// L'option **la plus proche du pouce est la plus utilisée** (Photo), la plus
/// éloignée la plus rare (Chercher). Elles apparaissent dans cet ordre, en
/// cascade : le regard suit le déploiement au lieu de recevoir trois éléments
/// d'un coup.
///
/// ## Ce widget occupe tout l'écran, pas seulement son coin
///
/// Il se place en `Positioned.fill` et **n'utilise pas** l'emplacement
/// `floatingActionButton` du `Scaffold`. La raison est le voile : il doit
/// couvrir toute la surface, or les options doivent rester **au-dessus** de
/// lui. Les empiler ici, dans un seul `Stack`, rend cet ordre explicite et
/// vérifiable. Passer par un `Overlay` place au contraire le voile par-dessus
/// tout, et les options deviennent alors intouchables — un tap referme le menu
/// au lieu de choisir.
///
/// Au repos, tout est en `IgnorePointer` sauf le cercle : le reste de l'écran
/// reste parfaitement utilisable.
class AddMealFab extends StatefulWidget {
  final VoidCallback onPhoto;
  final VoidCallback onVoice;
  final VoidCallback onSearch;

  /// Marge à réserver sous le bouton — la hauteur de la barre de navigation.
  ///
  /// Le shell est en `extendBody: true` : sans cette marge, le bouton se pose
  /// au ras du bas et disparaît derrière la barre.
  final double bottomInset;

  const AddMealFab({
    super.key,
    required this.onPhoto,
    required this.onVoice,
    required this.onSearch,
    this.bottomInset = 0,
  });

  /// Diamètre du bouton principal, et donc hauteur occupée au repos.
  static const double collapsedSize = 56;

  /// Marge droite du bouton, alignée sur celle du contenu.
  static const double _rightInset = 20;

  @override
  State<AddMealFab> createState() => _AddMealFabState();
}

class _AddMealFabState extends State<AddMealFab>
    with SingleTickerProviderStateMixin {
  /// Ouverture posée, fermeture plus vive : on s'attarde sur ce qui apparaît,
  /// pas sur ce qui s'en va. Une fermeture lente donne une impression de
  /// lourdeur à chaque abandon.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 180),
  );

  /// Menu ouvert du point de vue de l'utilisateur.
  bool _open = false;

  /// Options **présentes dans l'arbre**. Distinct de [_open] : elles doivent
  /// survivre à toute l'animation de fermeture, puis disparaître complètement.
  ///
  /// Les garder montées en permanence — même à hauteur nulle — laisserait leurs
  /// libellés trouvables et leurs zones cliquables actives : un tap fantôme
  /// au-dessus du bouton, et un gabarit au repos qui n'est plus celui d'un
  /// simple cercle.
  bool _mounted = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    if (_open) {
      _close();
    } else {
      setState(() {
        _open = true;
        _mounted = true;
      });
      _ctrl.forward();
    }
  }

  void _close() {
    if (!_open) return;
    setState(() => _open = false);
    // Le démontage n'a lieu qu'à la fin de la fermeture, sinon les options
    // disparaîtraient d'un coup au premier frame au lieu de se replier.
    _ctrl.reverse().then((_) {
      if (mounted) setState(() => _mounted = false);
    });
  }

  /// Referme d'abord, agit ensuite : la navigation part sur un écran déjà
  /// propre, sans voile résiduel pendant la transition.
  void _select(VoidCallback action) {
    HapticFeedback.selectionClick();
    _close();
    action();
  }

  /// Animation de la i-ème option, la plus proche du bouton d'abord.
  ///
  /// Les intervalles se **chevauchent** (0,00–0,70 / 0,12–0,82 / 0,24–0,94) :
  /// une cascade dont les étapes s'enchaînent sans se succéder franchement.
  /// Des intervalles disjoints donneraient trois apparitions distinctes, une
  /// saccade au lieu d'un mouvement.
  Animation<double> _stagger(int index) {
    final start = index * 0.12;
    return CurvedAnimation(
      parent: _ctrl,
      curve: Interval(start, start + 0.70, curve: Curves.easeOutCubic),
      // À la fermeture, tout se replie ensemble : décaler la sortie donnerait
      // l'impression que le menu résiste.
      reverseCurve: const Interval(0, 1, curve: Curves.easeInCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Le voile, SOUS les options ───────────────────────────────
        if (_mounted)
          Positioned.fill(
            child: _Scrim(animation: _ctrl, onTap: _close),
          ),

        // ── Le bouton et ses options, AU-DESSUS du voile ─────────────
        Positioned(
          right: AddMealFab._rightInset,
          bottom: widget.bottomInset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_mounted) ...[
                // Ordre visuel de haut en bas — donc du plus rare au plus
                // courant, le plus courant finissant collé au pouce.
                _option(
                  index: 2,
                  icon: Icons.search_rounded,
                  label: 'Chercher',
                  onTap: () => _select(widget.onSearch),
                ),
                _option(
                  index: 1,
                  icon: Icons.mic_rounded,
                  label: 'Vocal',
                  onTap: () => _select(widget.onVoice),
                ),
                _option(
                  index: 0,
                  icon: Icons.photo_camera_rounded,
                  label: 'Photo',
                  onTap: () => _select(widget.onPhoto),
                ),
                const SizedBox(height: 14),
              ],
              _mainButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _option({
    required int index,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final animation = _stagger(index);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value.clamp(0.0, 1.0);
        return Align(
          alignment: Alignment.centerRight,
          // `heightFactor` évite que l'apparition pousse le bouton principal
          // vers le bas : la pile grandit vers le haut, le cercle ne bouge pas.
          heightFactor: t,
          child: Opacity(
            opacity: t,
            child: Transform.translate(
              // Les options montent depuis le bouton au lieu d'apparaître sur
              // place : le mouvement dit d'où elles sortent.
              offset: Offset(0, 16 * (1 - t)),
              child: child,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _AddMealOption(icon: icon, label: label, onTap: onTap),
      ),
    );
  }

  Widget _mainButton() {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.rotate(
        // 135° : le « + » devient une croix. La rotation seule suffit à
        // signifier « ceci se referme », sans changer d'icône.
        angle: _ctrl.value * math.pi * 0.75,
        child: child,
      ),
      child: Semantics(
        button: true,
        label: _open ? 'Fermer le menu d\'ajout' : 'Ajouter un repas',
        child: SizedBox(
          width: AddMealFab.collapsedSize,
          height: AddMealFab.collapsedSize,
          child: Material(
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.accentGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.42),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: InkWell(
                onTap: _toggle,
                customBorder: const CircleBorder(),
                child: Icon(
                  Icons.add_rounded,
                  size: 28,
                  color: AppColors.onGradient,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Une option déployée : étiquette + cercle
// ─────────────────────────────────────────────────────────────────────────────

/// Une option du menu. Les trois sont **strictement identiques** en gabarit :
/// seuls l'icône et le mot changent.
///
/// L'étiquette est cliquable au même titre que le cercle — viser un mot est
/// plus facile que viser un disque de 46 px, et rien n'indique à l'utilisateur
/// que l'un serait inerte.
class _AddMealOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AddMealOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  /// Diamètre des options : volontairement plus petit que le bouton principal.
  /// Elles lui sont subordonnées, la taille le dit.
  static const double _size = 46;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_size / 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // L'étiquette n'est pas décorative : sans elle, l'utilisateur doit
            // deviner trois icônes, et le tap supplémentaire du menu n'est plus
            // compensé.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.card,
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 22, color: AppColors.accentText),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Le voile
// ─────────────────────────────────────────────────────────────────────────────

/// Voile plein écran affiché pendant le déploiement.
///
/// Il remplit trois rôles, pas seulement l'esthétique :
/// - il **détache** les options du contenu, qui cesse de leur faire concurrence ;
/// - il offre une **zone de sortie immense** : un tap n'importe où referme, au
///   lieu de devoir viser à nouveau le petit bouton ;
/// - il rend l'occultation **attendue** — c'est le moment où l'utilisateur a
///   demandé un menu, pas un masquage permanent qu'il n'a pas choisi.
class _Scrim extends StatelessWidget {
  final Animation<double> animation;
  final VoidCallback onTap;

  const _Scrim({required this.animation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: GestureDetector(
          onTap: onTap,
          // `opaque` : le voile intercepte les taps même là où il est
          // transparent. Sans cela, un tap dans une zone claire traverserait
          // et agirait sur le contenu masqué.
          behavior: HitTestBehavior.opaque,
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
        ),
      ),
    );
  }
}
