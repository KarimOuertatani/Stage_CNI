import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/exercise_query.dart';
import '../../data/workout_model.dart';
import 'exercise_visuals.dart';

/// Les briques de recherche partagées par tous les écrans du catalogue.
///
/// Bibliothèque, liste d'une zone du corps, sélecteur d'exercice d'un
/// programme : les trois cherchent dans le même catalogue et doivent le faire
/// de la même façon. Un champ de recherche qui se comporte différemment d'un
/// écran à l'autre est un champ de recherche qu'on n'ose plus utiliser.

/// Champ de recherche instantané.
///
/// ## Pourquoi aucun « debounce »
///
/// Le filtrage se fait en mémoire (voir [ExerciseQuery]) : il n'y a pas d'appel
/// réseau à ménager. Attendre 300 ms après chaque frappe n'économiserait rien
/// et rendrait la liste poussive. Elle se met à jour à la lettre près.
class ExerciseSearchField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String hint;
  final bool autofocus;

  const ExerciseSearchField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = 'Rechercher un exercice…',
    this.autofocus = false,
  });

  @override
  State<ExerciseSearchField> createState() => _ExerciseSearchFieldState();
}

class _ExerciseSearchFieldState extends State<ExerciseSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _hasFocus = _focus.hasFocus));
  }

  @override
  void didUpdateWidget(covariant ExerciseSearchField old) {
    super.didUpdateWidget(old);
    // Le texte peut être remis à zéro depuis l'extérieur (« tout effacer »).
    // On ne touche au contrôleur que dans ce cas : le réécrire à chaque frappe
    // replacerait le curseur en fin de ligne.
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(
        offset: widget.value.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasFocus ? AppColors.primary : AppColors.border,
          width: _hasFocus ? 1.6 : 1,
        ),
        boxShadow: _hasFocus
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.search_rounded,
            size: 21,
            color: _hasFocus ? AppColors.primaryText : AppColors.textHint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              style: AppTextStyles.bodyMedium,
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
              ),
              onChanged: widget.onChanged,
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                _controller.clear();
                widget.onChanged('');
              },
              icon: Icon(
                Icons.close_rounded,
                size: 19,
                color: AppColors.textHint,
              ),
              tooltip: 'Effacer',
              splashRadius: 20,
            )
          else
            const SizedBox(width: 10),
        ],
      ),
    );
  }
}

/// Bande de filtres rapides : le niveau en accès direct, le reste dans une
/// feuille.
///
/// ## Pourquoi le niveau est le seul filtre sorti de la feuille
///
/// C'est celui qu'on change le plus souvent et le seul dont dépend la
/// **sécurité** de la séance : proposer un arraché à quelqu'un qui débute n'est
/// pas une simple maladresse d'affichage. Matériel, type et tri sont des
/// réglages qu'on pose une fois — les mettre tous sur une même ligne aurait
/// donné une bande de dix pastilles illisible.
class ExerciseFilterBar extends StatelessWidget {
  final ExerciseQuery query;
  final ValueChanged<ExerciseQuery> onChanged;

  /// Catalogue courant : sert à ne proposer que le matériel et les types
  /// réellement présents. Un filtre « Kettlebell » qui ne renvoie jamais rien
  /// n'est pas un filtre, c'est un piège.
  final List<WorkoutModel> catalog;

  /// Affiche la pastille « Favoris ». Inutile là où la liste EST déjà celle
  /// des favoris.
  final bool showFavoritesChip;

  /// Marge horizontale interne. 20 px dans un écran, 0 dans une feuille qui
  /// pose déjà la sienne — sans ce réglage, la bande y démarrerait à 40 px du
  /// bord et ne serait plus alignée sur le champ de recherche au-dessus.
  final double horizontalPadding;

  const ExerciseFilterBar({
    super.key,
    required this.query,
    required this.onChanged,
    required this.catalog,
    this.showFavoritesChip = true,
    this.horizontalPadding = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        children: [
          _FilterChip(
            label: 'Filtres',
            icon: Icons.tune_rounded,
            selected: query.hasFilters,
            badge: query.activeFilterCount,
            color: AppColors.accent,
            onTap: () async {
              final updated = await showExerciseFiltersSheet(
                context,
                query: query,
                catalog: catalog,
              );
              if (updated != null) onChanged(updated);
            },
          ),
          const SizedBox(width: 8),
          _Separator(),
          const SizedBox(width: 8),
          for (final level in ExerciseLevel.values) ...[
            _FilterChip(
              label: level.label,
              selected: query.levels.contains(level),
              color: levelColor(level),
              onTap: () => onChanged(
                query.copyWith(levels: ExerciseQuery.toggle(query.levels, level)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (showFavoritesChip) ...[
            _FilterChip(
              label: 'Favoris',
              icon: Icons.star_rounded,
              selected: query.favoritesOnly,
              color: AppColors.warning,
              onTap: () =>
                  onChanged(query.copyWith(favoritesOnly: !query.favoritesOnly)),
            ),
            const SizedBox(width: 8),
          ],
          _FilterChip(
            label: 'Vidéo',
            icon: Icons.play_circle_outline_rounded,
            selected: query.withVideoOnly,
            color: AppColors.info,
            onTap: () =>
                onChanged(query.copyWith(withVideoOnly: !query.withVideoOnly)),
          ),
          SizedBox(width: horizontalPadding),
        ],
      ),
    );
  }
}

/// Ligne de résumé : combien de résultats, comment ils sont triés, et de quoi
/// tout remettre à zéro.
class ExerciseResultHeader extends StatelessWidget {
  final int count;
  final ExerciseQuery query;
  final ValueChanged<ExerciseQuery> onChanged;

  const ExerciseResultHeader({
    super.key,
    required this.count,
    required this.query,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 2),
      child: Row(
        children: [
          Text(
            '$count exercice${count > 1 ? 's' : ''}',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (query.hasFilters) ...[
            const SizedBox(width: 10),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(query.clearedFilters());
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  'Tout effacer',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ),
          ],
          const Spacer(),
          PopupMenuButton<ExerciseSort>(
            initialValue: query.sort,
            color: AppColors.card,
            tooltip: 'Trier',
            onSelected: (sort) {
              HapticFeedback.selectionClick();
              onChanged(query.copyWith(sort: sort));
            },
            itemBuilder: (_) => [
              for (final sort in ExerciseSort.values)
                PopupMenuItem(
                  value: sort,
                  child: Row(
                    children: [
                      Icon(
                        sort == query.sort
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 17,
                        color: sort == query.sort
                            ? AppColors.primaryText
                            : AppColors.textHint,
                      ),
                      const SizedBox(width: 10),
                      Text(sort.label, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_vert_rounded,
                    size: 17,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    query.sort.label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Feuille des filtres détaillés : matériel, type, tri.
///
/// Renvoie la requête modifiée, ou `null` si l'adhérent a refermé sans rien
/// valider. Les changements ne s'appliquent qu'à la validation : voir la liste
/// se réorganiser sous la feuille pendant qu'on coche est désorientant.
Future<ExerciseQuery?> showExerciseFiltersSheet(
  BuildContext context, {
  required ExerciseQuery query,
  required List<WorkoutModel> catalog,
}) {
  return showModalBottomSheet<ExerciseQuery>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FiltersSheet(query: query, catalog: catalog),
  );
}

class _FiltersSheet extends StatefulWidget {
  final ExerciseQuery query;
  final List<WorkoutModel> catalog;

  const _FiltersSheet({required this.query, required this.catalog});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late ExerciseQuery _draft = widget.query;

  /// Matériel réellement présent dans le catalogue affiché, par ordre
  /// alphabétique de libellé.
  List<({String value, String label})> get _equipments {
    final seen = <String, String>{};
    for (final e in widget.catalog) {
      final value = e.equipment;
      final label = e.equipmentLabel;
      if (value != null && label != null) seen[value] = label;
    }
    final list = [
      for (final entry in seen.entries)
        (value: entry.key, label: entry.value),
    ];
    list.sort((a, b) => a.label.compareTo(b.label));
    return list;
  }

  List<String> get _types {
    final seen = <String>{};
    for (final e in widget.catalog) {
      final label = e.typeLabel;
      if (label != null) seen.add(label);
    }
    final list = seen.toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final equipments = _equipments;
    final types = _types;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Filtrer', style: AppTextStyles.headingSmall),
                const Spacer(),
                if (_draft.hasFilters)
                  TextButton(
                    onPressed: () =>
                        setState(() => _draft = _draft.clearedFilters()),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Tout effacer'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SheetSection(
                      title: 'Niveau',
                      icon: Icons.signal_cellular_alt_rounded,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final level in ExerciseLevel.values)
                            _FilterChip(
                              label: level.label,
                              selected: _draft.levels.contains(level),
                              color: levelColor(level),
                              onTap: () => setState(() {
                                _draft = _draft.copyWith(
                                  levels: ExerciseQuery.toggle(
                                    _draft.levels,
                                    level,
                                  ),
                                );
                              }),
                            ),
                        ],
                      ),
                    ),
                    if (equipments.isNotEmpty)
                      _SheetSection(
                        title: 'Matériel',
                        icon: Icons.fitness_center_rounded,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final eq in equipments)
                              _FilterChip(
                                label: eq.label,
                                selected: _draft.equipments.contains(eq.value),
                                color: AppColors.accent,
                                onTap: () => setState(() {
                                  _draft = _draft.copyWith(
                                    equipments: ExerciseQuery.toggle(
                                      _draft.equipments,
                                      eq.value,
                                    ),
                                  );
                                }),
                              ),
                          ],
                        ),
                      ),
                    if (types.isNotEmpty)
                      _SheetSection(
                        title: 'Type',
                        icon: Icons.category_outlined,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final type in types)
                              _FilterChip(
                                label: type,
                                selected: _draft.types.contains(type),
                                color: AppColors.info,
                                onTap: () => setState(() {
                                  _draft = _draft.copyWith(
                                    types: ExerciseQuery.toggle(
                                      _draft.types,
                                      type,
                                    ),
                                  );
                                }),
                              ),
                          ],
                        ),
                      ),
                    _SheetSection(
                      title: 'Afficher',
                      icon: Icons.visibility_outlined,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChip(
                            label: 'Favoris uniquement',
                            icon: Icons.star_rounded,
                            selected: _draft.favoritesOnly,
                            color: AppColors.warning,
                            onTap: () => setState(() {
                              _draft = _draft.copyWith(
                                favoritesOnly: !_draft.favoritesOnly,
                              );
                            }),
                          ),
                          _FilterChip(
                            label: 'Avec vidéo',
                            icon: Icons.play_circle_outline_rounded,
                            selected: _draft.withVideoOnly,
                            color: AppColors.info,
                            onTap: () => setState(() {
                              _draft = _draft.copyWith(
                                withVideoOnly: !_draft.withVideoOnly,
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    _SheetSection(
                      title: 'Trier par',
                      icon: Icons.swap_vert_rounded,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final sort in ExerciseSort.values)
                            _FilterChip(
                              label: sort.label,
                              selected: _draft.sort == sort,
                              color: AppColors.primary,
                              onTap: () => setState(
                                () => _draft = _draft.copyWith(sort: sort),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_draft),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onGradient,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Voir les résultats',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.onGradient,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SheetSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.accentText),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Pastille de filtre : contour au repos, teintée et bordée quand elle est
/// active. L'état actif doit se voir d'un coup d'œil sur une bande qui défile.
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  /// Compteur affiché en exposant (nombre de filtres actifs).
  final int badge;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.icon,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? color : AppColors.textSecondary;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : AppColors.card,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.55)
                : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Text(
                  '$badge',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.onGradient,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(width: 1, height: 20, color: AppColors.border),
    );
  }
}
