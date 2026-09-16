import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/food_model.dart';
import '../../data/meal_model.dart';
import '../providers/food_search_provider.dart';
import 'macro_chip.dart';
import 'meal_type_chips.dart';

/// Feuille d'ajout d'aliment en **deux étapes**, dans une seule surface :
///
/// 1. **Recherche** — l'adhérent tape un nom **en français**, les résultats
///    USDA arrivent traduits, avec leurs macros pour 100 g ;
/// 2. **Quantité** — il ajuste les grammes et voit les macros **se recalculer
///    en direct**, puis valide.
///
/// Aucune saisie de calories ou de macros : c'est tout l'objet de la
/// fonctionnalité. Un lien discret permet de basculer en saisie manuelle pour
/// les cas non couverts (repas maison, restaurant).
Future<void> showFoodSearchSheet(
  BuildContext context, {
  required MealType initialType,
  required Future<String?> Function(
    FoodSearchResult food,
    MealType type,
    double grams,
  )
  onConfirm,
  required VoidCallback onManualEntry,
}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Une feuille haute : la recherche a besoin de place pour ses résultats.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.92,
    ),
    builder: (_) => _FoodSearchSheet(
      initialType: initialType,
      onConfirm: onConfirm,
      onManualEntry: onManualEntry,
    ),
  );
}

class _FoodSearchSheet extends ConsumerStatefulWidget {
  final MealType initialType;
  final Future<String?> Function(
    FoodSearchResult food,
    MealType type,
    double grams,
  )
  onConfirm;
  final VoidCallback onManualEntry;

  const _FoodSearchSheet({
    required this.initialType,
    required this.onConfirm,
    required this.onManualEntry,
  });

  @override
  ConsumerState<_FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends ConsumerState<_FoodSearchSheet> {
  final _searchController = TextEditingController();

  late MealType _type = widget.initialType;

  /// Aliment sélectionné : non nul ⇒ on est à l'étape « quantité ».
  FoodSearchResult? _selected;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _select(FoodSearchResult food) {
    HapticFeedback.selectionClick();
    // On referme le clavier avant de passer à l'étape quantité, sinon la
    // feuille reste comprimée par les insets pendant l'animation.
    FocusScope.of(context).unfocus();
    setState(() => _selected = food);
  }

  void _backToSearch() {
    HapticFeedback.selectionClick();
    setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final atQuantityStep = _selected != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              _grabber(),
              const SizedBox(height: 14),
              // Le changement d'étape se fait par fondu + glissement latéral :
              // on garde le contexte visuel de la feuille, sans naviguer.
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(atQuantityStep ? 0.06 : -0.06, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: atQuantityStep
                      ? _QuantityStep(
                          key: ValueKey(_selected!.key),
                          food: _selected!,
                          type: _type,
                          onBack: _backToSearch,
                          onConfirm: (grams) =>
                              widget.onConfirm(_selected!, _type, grams),
                        )
                      : _searchStep(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grabber() => Container(
    width: 40,
    height: 5,
    decoration: BoxDecoration(
      color: AppColors.border,
      borderRadius: BorderRadius.circular(2.5),
    ),
  );

  // ── Étape 1 : recherche ─────────────────────────────────────────

  Widget _searchStep() {
    final state = ref.watch(foodSearchProvider);
    final notifier = ref.read(foodSearchProvider.notifier);

    return Column(
      key: const ValueKey('search'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ajouter un aliment',
                      style: AppTextStyles.headingMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(40, 40),
                    ),
                    tooltip: 'Fermer',
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Les calories et les macros sont calculées automatiquement.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 16),
              MealTypeChips(
                selected: _type,
                onChanged: (t) => setState(() => _type = t),
              ),
              const SizedBox(height: 14),
              _searchField(state, notifier),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Flexible(child: _searchBody(state, notifier)),
        _manualEntryFooter(),
      ],
    );
  }

  Widget _searchField(FoodSearchState state, FoodSearchNotifier notifier) {
    return TextField(
      controller: _searchController,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: notifier.onQueryChanged,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'ex : poulet, riz, banane, yaourt…',
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: AppColors.accentText,
          size: 22,
        ),
        // Indicateur discret pendant la frappe : évite de faire clignoter
        // toute la liste à chaque caractère.
        suffixIcon: state.isLoading
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accentText,
                  ),
                ),
              )
            : (state.query.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        size: 20,
                        color: AppColors.textHint,
                      ),
                      tooltip: 'Effacer',
                      onPressed: () {
                        _searchController.clear();
                        notifier.onQueryChanged('');
                      },
                    )
                  : null),
        filled: true,
        fillColor: AppColors.glassWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.accent, width: 1.6),
        ),
      ),
    );
  }

  Widget _searchBody(FoodSearchState state, FoodSearchNotifier notifier) {
    // 1) Erreur (quota USDA, réseau…) — le message vient du backend.
    if (state.errorMessage != null && state.results.isEmpty) {
      return SingleChildScrollView(
        child: AppErrorState(
          message: state.errorMessage,
          onRetry: notifier.retry,
        ),
      );
    }

    // 2) Champ vide : on propose les aliments déjà consommés.
    if (state.showsRecent) {
      if (state.isLoadingRecent) {
        return const AppListSkeleton(itemCount: 4, itemHeight: 76);
      }
      if (state.recent.isEmpty) {
        return _hint(
          icon: Icons.search_rounded,
          title: 'Cherchez un aliment',
          message:
              'Tapez au moins 2 lettres. Les aliments que vous ajoutez apparaîtront ici pour un accès rapide.',
        );
      }
      return _resultList(
        state.recent,
        header: 'Vos aliments habituels',
        headerIcon: Icons.history_rounded,
      );
    }

    // 3) Première recherche en cours : squelette plutôt qu'un écran vide.
    if (state.isLoading && state.results.isEmpty) {
      return const AppListSkeleton(itemCount: 5, itemHeight: 76);
    }

    // 4) Recherche aboutie sans résultat.
    if (state.results.isEmpty && state.hasSearched) {
      return _hint(
        icon: Icons.no_food_rounded,
        title: 'Aucun aliment trouvé',
        message:
            'Essayez un terme plus simple : « poulet » plutôt que « blanc de poulet fermier ». Pour un plat maison ou un produit absent de la base, utilisez la saisie manuelle.',
      );
    }

    return _resultList(state.results);
  }

  Widget _resultList(
    List<FoodSearchResult> foods, {
    String? header,
    IconData? headerIcon,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      itemCount: foods.length + (header != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (header != null && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 2),
            child: Row(
              children: [
                Icon(headerIcon, size: 15, color: AppColors.textHint),
                const SizedBox(width: 7),
                Text(
                  header,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          );
        }
        final food = foods[index - (header != null ? 1 : 0)];
        return _FoodResultTile(food: food, onTap: () => _select(food))
            .animate()
            .fadeIn(duration: 220.ms, delay: (index * 22).ms)
            .slideY(begin: 0.06);
      },
    );
  }

  Widget _hint({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 30),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.glassWhite,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, size: 28, color: AppColors.accentText),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _manualEntryFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        children: [
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.onManualEntry();
            },
            icon: const Icon(Icons.edit_note_rounded, size: 19),
            label: const Text('Aliment absent ? Saisie manuelle'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              minimumSize: const Size.fromHeight(42),
            ),
          ),
          const _SourcesCredit(),
        ],
      ),
    );
  }
}

/// Crédit des bases de données interrogées.
///
/// **Ce n'est pas décoratif : Open Food Facts publie ses données sous licence
/// ODbL, qui impose de citer la source à toute réutilisation.** La mention est
/// placée ici, au pied de la recherche, parce que c'est l'écran où ces données
/// sont effectivement montrées — pas enterrée dans un menu que personne
/// n'ouvre. Elle crédite USDA dans le même geste.
class _SourcesCredit extends StatelessWidget {
  const _SourcesCredit();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        'Données : USDA FoodData Central · Open Food Facts (ODbL)',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textHint,
          fontSize: 9,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ligne de résultat
// ─────────────────────────────────────────────────────────────────────────────

class _FoodResultTile extends StatelessWidget {
  final FoodSearchResult food;
  final VoidCallback onTap;

  const _FoodResultTile({required this.food, required this.onTap});

  /// Produit emballé issu d'Open Food Facts (et pas encore en catalogue).
  bool get _isPackaged => food.source == FoodResultSource.openFoodFacts;

  @override
  Widget build(BuildContext context) {
    final kcal = food.caloriesPer100g?.round();
    final subtitle = food.subtitle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.glassWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null || _isPackaged) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          // Les fiches Open Food Facts sont contributives :
                          // leur qualité est plus inégale que celle d'USDA.
                          // Le signaler discrètement invite à vérifier les
                          // valeurs, sans disqualifier la source.
                          if (_isPackaged) ...[
                            _SourceTag(),
                            const SizedBox(width: 6),
                          ],
                          if (subtitle != null)
                            Flexible(
                              child: Text(
                                subtitle,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textHint,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    MacroChipRow(
                      protein: food.proteinPer100g ?? 0,
                      carbs: food.carbsPer100g ?? 0,
                      fat: food.fatPer100g ?? 0,
                      fiber: food.fiberPer100g,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (kcal != null) ...[
                    Text(
                      '$kcal',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.accentText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'kcal /100 g',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textHint,
                        fontSize: 9,
                      ),
                    ),
                  ] else
                    Text(
                      '—',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marqueur discret d'un produit du commerce (source Open Food Facts).
class _SourceTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Produit emballé',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textHint,
          fontSize: 9,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Étape 2 : quantité + aperçu temps réel
// ─────────────────────────────────────────────────────────────────────────────

class _QuantityStep extends StatefulWidget {
  final FoodSearchResult food;
  final MealType type;
  final VoidCallback onBack;

  /// Renvoie `null` si l'ajout a réussi, sinon le message d'erreur.
  final Future<String?> Function(double grams) onConfirm;

  const _QuantityStep({
    super.key,
    required this.food,
    required this.type,
    required this.onBack,
    required this.onConfirm,
  });

  @override
  State<_QuantityStep> createState() => _QuantityStepState();
}

class _QuantityStepState extends State<_QuantityStep> {
  /// Portions usuelles : couvre la grande majorité des cas en un seul geste.
  static const List<double> _presets = [30, 50, 100, 150, 200, 250];

  /// Borne haute du curseur (alignée sur la validation serveur : 5000 g max).
  static const double _sliderMax = 500;

  double _grams = 100;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    final error = await widget.onConfirm(_grams);
    if (!mounted) return;

    if (error != null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error, style: AppTextStyles.bodyMedium),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.food.previewFor(_grams);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 18),
          _caloriesPreview(preview),
          const SizedBox(height: 16),
          _quantitySelector(),
          const SizedBox(height: 18),
          _macroBreakdown(preview),
          const SizedBox(height: 22),
          PrimaryButton(
            label: _submitting
                ? 'Ajout en cours…'
                : 'Ajouter à ${mealTypeLabel(widget.type).toLowerCase()}',
            icon: Icons.check_rounded,
            gradient: AppColors.accentGradient,
            glowColor: AppColors.accent,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: widget.onBack,
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.glassWhite,
            minimumSize: const Size(40, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.border),
            ),
          ),
          tooltip: 'Retour à la recherche',
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.food.name,
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.food.subtitle != null)
                Text(
                  widget.food.subtitle!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textHint,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Bloc calories : c'est la valeur que l'adhérent regarde en premier, elle
  /// s'anime à chaque changement de quantité.
  Widget _caloriesPreview(MacroPreview preview) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: AppColors.isDark ? 0.18 : 0.12),
            AppColors.primary.withValues(alpha: AppColors.isDark ? 0.14 : 0.09),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Row(
              key: ValueKey(preview.calories),
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${preview.calories}',
                  style: AppTextStyles.displayMedium.copyWith(
                    color: AppColors.accentText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'kcal',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'pour ${_grams.round()} g',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _quantitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quantité', style: AppTextStyles.labelMedium),
            Text(
              '${_grams.round()} g',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.accentText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: AppColors.border,
            thumbColor: AppColors.accent,
            overlayColor: AppColors.accent.withValues(alpha: 0.18),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: _grams.clamp(5, _sliderMax),
            min: 5,
            max: _sliderMax,
            // Pas de 5 g : assez fin pour être précis, assez grossier pour
            // rester confortable au doigt.
            divisions: ((_sliderMax - 5) / 5).round(),
            onChanged: (v) => setState(() => _grams = v.roundToDouble()),
          ),
        ),
        const SizedBox(height: 2),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in _presets)
              _PresetChip(
                grams: preset,
                selected: _grams == preset,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _grams = preset);
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _macroBreakdown(MacroPreview preview) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_rounded,
                size: 15,
                color: AppColors.textHint,
              ),
              const SizedBox(width: 7),
              Text(
                'Macronutriments',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _macroLine('Protéines', preview.protein, AppColors.macroProtein),
          _macroLine('Glucides', preview.carbs, AppColors.macroCarbs),
          _macroLine('Lipides', preview.fat, AppColors.macroFat),
          if (preview.fiber != null)
            _macroLine('Fibres', preview.fiber!, AppColors.macroFiber),
        ],
      ),
    );
  }

  Widget _macroLine(String label, double grams, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            grams >= 10
                ? '${grams.round()} g'
                : '${grams.toStringAsFixed(1)} g',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final double grams;
  final bool selected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.grams,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.accentGradient : null,
          color: selected ? null : AppColors.glassWhite,
          borderRadius: BorderRadius.circular(100),
          border: selected ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          '${grams.round()} g',
          style: AppTextStyles.labelSmall.copyWith(
            color: selected ? AppColors.onGradient : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
