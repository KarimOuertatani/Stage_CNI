import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/navigation/main_shell.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/neon_badge.dart';
import '../../../../core/widgets/animated_progress_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/nutrition_provider.dart';
import '../widgets/add_meal_fab.dart';
import '../widgets/food_search_sheet.dart';
import '../widgets/meal_card.dart';
import '../widgets/meal_type_chips.dart';
import '../widgets/quantity_edit_sheet.dart';
import '../../data/meal_model.dart';
import '../../../../core/widgets/screen_background.dart';

/// Écran Nutrition — la saisie doit être la plus rapide possible
/// (point d'abandon n°1 sur ce type d'app).
///
/// Parcours principal : **rechercher un aliment → régler la quantité**. Les
/// calories et les macros sont calculées par le serveur depuis USDA FoodData
/// Central ; l'adhérent ne saisit plus aucun chiffre nutritionnel. La saisie
/// manuelle reste accessible en repli (repas maison, restaurant).
class MealsScreen extends ConsumerWidget {
  const MealsScreen({super.key});

  /// Parcours nominal : recherche d'aliment.
  void _showFoodSearch(
    BuildContext context,
    WidgetRef ref, {
    MealType type = MealType.breakfast,
  }) {
    showFoodSearchSheet(
      context,
      initialType: type,
      onConfirm: (food, mealType, grams) => ref
          .read(nutritionProvider.notifier)
          .addFoodEntry(food: food, type: mealType, grams: grams),
      onManualEntry: () => _showManualSheet(context, ref, type: type),
    );
  }

  /// Repli : saisie manuelle complète des valeurs.
  void _showManualSheet(
    BuildContext context,
    WidgetRef ref, {
    MealType type = MealType.breakfast,
  }) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMealSheet(
        initialType: type,
        onSubmit: (name, mealType, calories, protein, carbs, fat) {
          ref
              .read(nutritionProvider.notifier)
              .addMeal(name, mealType, calories, protein, carbs, fat);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nutritionState = ref.watch(nutritionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition')),
      // ── Une seule porte d'entrée pour ajouter un repas ──────────────────
      //
      // Elles étaient d'abord éparpillées — une loupe dans l'AppBar, un « + »
      // flottant, un lien « Rechercher » au-dessus de la liste — qui ouvraient
      // tous le MÊME écran. Puis réunies dans une barre à trois cases, qui
      // masquait en permanence le bas du journal.
      //
      // Désormais : un cercle unique, qui déploie les trois options à la
      // demande (voir `AddMealFab`). L'écran ne paie plus de surface pour des
      // actions qu'on déclenche quelques fois par jour.
      //
      // Le bouton n'est PAS dans l'emplacement `floatingActionButton` du
      // Scaffold : son voile doit couvrir tout l'écran tout en restant SOUS les
      // options. Il se place donc en `Positioned.fill` par-dessus le contenu,
      // et gère cet empilement lui-même.
      body: Stack(
        children: [
          ScreenBackground(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _DateBar(
                    state: nutritionState,
                    onPrev: () =>
                        ref.read(nutritionProvider.notifier).previousDay(),
                    onNext: () =>
                        ref.read(nutritionProvider.notifier).nextDay(),
                    onToday: () =>
                        ref.read(nutritionProvider.notifier).goToday(),
                    onPick: () => _pickDay(context, ref, nutritionState),
                  ),
                  Expanded(child: _buildBody(context, ref, nutritionState)),
                ],
              ),
            ),
          ),
          // ⚠️ L'animation reste À L'INTÉRIEUR du `Positioned.fill`.
          // `Positioned(...).animate()` renverrait un widget qui n'est plus un
          // `Positioned` : le `Stack` le traiterait comme un enfant libre, et
          // comme `AddMealFab` n'a que des enfants positionnés, sa taille
          // intrinsèque est nulle — le bouton disparaîtrait purement et
          // simplement.
          Positioned.fill(
            child: AddMealFab(
              // Le shell est en `extendBody: true` : cet écran s'étend derrière
              // la barre de navigation. Sans cette marge, le bouton se pose au
              // ras du bas et disparaît dessous.
              bottomInset: MainShell.heightOf(context),
              onPhoto: () => context.push('/nutrition/photo'),
              onVoice: () => context.push('/nutrition/voice'),
              onSearch: () => _showFoodSearch(context, ref),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDay(
    BuildContext context,
    WidgetRef ref,
    NutritionState state,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: state.selectedDay,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Choisir un jour',
    );
    if (picked != null) {
      ref.read(nutritionProvider.notifier).loadDay(picked);
    }
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, NutritionState state) {
    if (state.isLoading) {
      return Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ShimmerBox(
              width: double.infinity,
              height: 124,
              borderRadius: 22,
            ),
          ),
          const SizedBox(height: 20),
          const Expanded(child: AppListSkeleton(itemCount: 3, itemHeight: 150)),
        ],
      );
    }

    if (state.errorMessage != null && state.meals.isEmpty) {
      return AppErrorState(
        message: 'Impossible de charger vos repas.',
        onRetry: () =>
            ref.read(nutritionProvider.notifier).loadDay(state.selectedDay),
      );
    }

    final progress = (state.consumedCalories / state.dailyGoal).clamp(0.0, 1.0);
    final overGoal = state.consumedCalories > state.dailyGoal;

    return Column(
      children: [
        // ── Bilan calorique du jour ─────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 22,
            child: Column(
              children: [
                Row(
                  children: [
                    AnimatedRingProgress(
                      value: progress,
                      size: 84,
                      strokeWidth: 8,
                      color: overGoal ? AppColors.warning : AppColors.accent,
                      center: CountUpNumber(
                        to: progress * 100,
                        suffix: '%',
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Calories consommées',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              CountUpNumber(
                                to: state.consumedCalories.toDouble(),
                                style: AppTextStyles.statValue.copyWith(
                                  color: overGoal
                                      ? AppColors.warningText
                                      : AppColors.accentText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '/ ${state.dailyGoal} kcal',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                          if (overGoal) ...[
                            const SizedBox(height: 6),
                            NeonBadge(
                              label: 'Objectif dépassé',
                              color: AppColors.warning,
                              icon: Icons.info_outline_rounded,
                              fontSize: 10,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _MacroMeter(
                      label: 'Protéines',
                      grams: state.consumedProtein,
                      color: AppColors.macroProtein,
                    ),
                    const SizedBox(width: 14),
                    _MacroMeter(
                      label: 'Glucides',
                      grams: state.consumedCarbs,
                      color: AppColors.macroCarbs,
                    ),
                    const SizedBox(width: 14),
                    _MacroMeter(
                      label: 'Lipides',
                      grams: state.consumedFat,
                      color: AppColors.macroFat,
                    ),
                    // Les fibres ne sont affichées que si la donnée existe :
                    // beaucoup d'aliments USDA ne la renseignent pas.
                    if (state.consumedFiber > 0) ...[
                      const SizedBox(width: 14),
                      _MacroMeter(
                        label: 'Fibres',
                        grams: state.consumedFiber,
                        color: AppColors.macroFiber,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.05),
        const SizedBox(height: 12),

        // ── Header liste ────────────────────────────────────────
        // Pas de bouton d'ajout ici : la barre d'actions du bas s'en charge.
        // Le « + » de chaque section, lui, reste — il n'ouvre pas la même
        // chose, il pré-sélectionne le repas concerné.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: AppColors.accentGlow,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                state.isToday ? 'Repas du jour' : 'Repas',
                style: AppTextStyles.headingSmall,
              ),
            ],
          ),
        ).animate().fadeIn(delay: 150.ms),
        const SizedBox(height: 12),

        // ── Liste des repas, regroupée par moment de la journée ──
        Expanded(
          child: state.meals.isEmpty
              ? AppEmptyState(
                  icon: Icons.restaurant_rounded,
                  title: state.isToday
                      ? 'Aucun repas aujourd\'hui'
                      : 'Aucun repas ce jour-là',
                  message: state.isToday
                      ? 'Cherchez un aliment : les calories et les macros sont calculées pour vous.'
                      : 'Aucune entrée enregistrée pour cette journée.',
                  actionLabel: 'Rechercher un aliment',
                  onAction: () => _showFoodSearch(context, ref),
                )
              : _mealsList(context, ref, state),
        ),
      ],
    );
  }

  /// Journal regroupé par repas : chaque section porte son propre total de
  /// calories et un bouton d'ajout qui pré-sélectionne le bon moment.
  Widget _mealsList(BuildContext context, WidgetRef ref, NutritionState state) {
    final grouped = state.mealsByType;
    final sections = grouped.keys.toList();
    var animationIndex = 0;

    return ListView.builder(
      // La marge basse doit dégager la barre de navigation ET le bouton
      // d'ajout, sinon la dernière carte du journal reste définitivement
      // à moitié cachée — impossible d'aller la lire en faisant défiler.
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MainShell.heightOf(context) + AddMealFab.collapsedSize + 16,
      ),
      itemCount: sections.length,
      itemBuilder: (context, sectionIndex) {
        final type = sections[sectionIndex];
        final items = grouped[type]!;
        final sectionCalories = items.fold<int>(0, (s, m) => s + m.calories);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MealSectionHeader(
              type: type,
              calories: sectionCalories,
              itemCount: items.length,
              onAdd: () => _showFoodSearch(context, ref, type: type),
            ),
            const SizedBox(height: 10),
            for (final meal in items)
              MealCard(
                    meal: meal,
                    onEditQuantity: meal.isFromCatalog
                        ? () => showQuantityEditSheet(
                            context,
                            meal: meal,
                            onConfirm: (grams) => ref
                                .read(nutritionProvider.notifier)
                                .updateQuantity(meal.id, grams),
                          )
                        : null,
                    onDelete: () => ref
                        .read(nutritionProvider.notifier)
                        .deleteMeal(meal.id),
                  )
                  .animate()
                  .fadeIn(
                    delay: (150 + (animationIndex++) * 45).ms,
                    duration: 380.ms,
                  )
                  .slideY(begin: 0.05),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
}

/// En-tête d'une section de repas : icône, libellé, total et ajout ciblé.
class _MealSectionHeader extends StatelessWidget {
  final MealType type;
  final int calories;
  final int itemCount;
  final VoidCallback onAdd;

  const _MealSectionHeader({
    required this.type,
    required this.calories,
    required this.itemCount,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(mealTypeIcon(type), size: 17, color: AppColors.accentText),
        const SizedBox(width: 8),
        Text(
          mealTypeLabel(type),
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.glassWhite,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            '$calories kcal',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onAdd,
          icon: Icon(Icons.add_rounded, size: 20, color: AppColors.accentText),
          tooltip: 'Ajouter à ${mealTypeLabel(type).toLowerCase()}',
          style: IconButton.styleFrom(minimumSize: const Size(36, 36)),
        ),
      ],
    );
  }
}

/// Barre de navigation entre les jours du journal alimentaire.
class _DateBar extends StatelessWidget {
  final NutritionState state;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onPick;

  const _DateBar({
    required this.state,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onPick,
  });

  static const _months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  static const _days = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

  String _label() {
    final d = state.selectedDay;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Aujourd\'hui';
    if (diff == 1) return 'Hier';
    return '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            enabled: true,
            onTap: () {
              HapticFeedback.selectionClick();
              onPrev();
            },
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onPick();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.glassWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 15,
                      color: AppColors.accentText,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _label(),
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!state.isToday) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onToday();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.accentGradient,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'Aujourd\'hui',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.onGradient,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Jour suivant désactivé si on est déjà aujourd'hui (pas de futur).
          _NavButton(
            icon: Icons.chevron_right_rounded,
            enabled: !state.isToday,
            onTap: () {
              HapticFeedback.selectionClick();
              onNext();
            },
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: IconButton(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, color: AppColors.textPrimary),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.glassWhite,
          minimumSize: const Size(42, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }
}

/// Compteur macro compact (bilan du jour).
class _MacroMeter extends StatelessWidget {
  final String label;
  final int grams;
  final Color color;

  const _MacroMeter({
    required this.label,
    required this.grams,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Libellé AU-DESSUS de la valeur, et non à côté : avec les fibres, le
    // bilan peut afficher 4 compteurs. Sur un écran de 360 dp cela laisse
    // ~59 px par colonne — « Protéines » et « 48 g » côte à côte débordaient.
    // Empilés, chacun dispose de toute la largeur de sa colonne.
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$grams g',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedProgressBar(
            value: (grams / 150).clamp(0.0, 1.0),
            height: 4,
            color: color,
            showGlow: false,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet de saisie MANUELLE — repli quand l'aliment n'est pas dans le catalogue
// (repas maison, restaurant, produit local). Le parcours nominal reste la
// recherche d'aliment, qui ne demande qu'une quantité.
// ─────────────────────────────────────────────────────────────────────────────

class _AddMealSheet extends StatefulWidget {
  final MealType initialType;
  final void Function(
    String name,
    MealType type,
    int calories,
    int protein,
    int carbs,
    int fat,
  )
  onSubmit;

  const _AddMealSheet({
    required this.onSubmit,
    this.initialType = MealType.breakfast,
  });

  @override
  State<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends State<_AddMealSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  late MealType _type = widget.initialType;

  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  String? _validateNumber(String? val, {required bool required}) {
    if (val == null || val.isEmpty) {
      return required ? 'Requis' : null;
    }
    final n = int.tryParse(val);
    if (n == null || n < 0) return 'Nombre invalide';
    if (n > 5000) return 'Trop élevé';
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.mediumImpact();
    widget.onSubmit(
      _name.text.trim(),
      _type,
      int.tryParse(_calories.text) ?? 0,
      int.tryParse(_protein.text) ?? 0,
      int.tryParse(_carbs.text) ?? 0,
      int.tryParse(_fat.text) ?? 0,
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text('Repas ajouté !', style: AppTextStyles.bodyMedium),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Saisie manuelle', style: AppTextStyles.headingMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Pour un aliment absent du catalogue. Sinon, la recherche calcule tout automatiquement.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Même sélecteur que la recherche d'aliment (composant partagé).
                  MealTypeChips(
                    selected: _type,
                    onChanged: (t) => setState(() => _type = t),
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _name,
                    hint: 'ex: Omelette & Avocat',
                    label: 'Nom du repas',
                    accentColor: AppColors.accent,
                    autofocus: true,
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Donnez un nom à ce repas'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _calories,
                          hint: '350',
                          label: 'Calories (kcal)',
                          keyboardType: TextInputType.number,
                          accentColor: AppColors.accent,
                          validator: (v) => _validateNumber(v, required: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: _protein,
                          hint: '25',
                          label: 'Protéines (g)',
                          keyboardType: TextInputType.number,
                          accentColor: AppColors.accent,
                          validator: (v) => _validateNumber(v, required: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _carbs,
                          hint: '40',
                          label: 'Glucides (g)',
                          keyboardType: TextInputType.number,
                          accentColor: AppColors.accent,
                          validator: (v) => _validateNumber(v, required: false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: _fat,
                          hint: '12',
                          label: 'Lipides (g)',
                          keyboardType: TextInputType.number,
                          accentColor: AppColors.accent,
                          validator: (v) => _validateNumber(v, required: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  PrimaryButton(
                    label: 'Enregistrer',
                    icon: Icons.check_rounded,
                    gradient: AppColors.accentGradient,
                    glowColor: AppColors.accent,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
