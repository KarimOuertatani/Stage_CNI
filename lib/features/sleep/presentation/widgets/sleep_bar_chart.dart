import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/sleep_models.dart';

/// L'histogramme de la semaine : une barre par jour, du lundi au dimanche.
///
/// ## Ce que la zone idéale change
///
/// Une bande horizontale translucide marque l'intervalle 7 h – 9 h, **derrière**
/// les barres. C'est elle qui rend l'histogramme lisible d'un coup d'œil : sans
/// repère, sept barres de hauteurs différentes ne disent rien — on voit que
/// mardi est plus haut que mercredi, pas si l'un des deux est suffisant. Avec
/// la bande, la question devient « est-ce que ma barre atteint la zone ? », et
/// elle se répond sans lire un seul chiffre.
///
/// ## Les jours creux se voient
///
/// Un jour sans saisie garde sa colonne, avec un socle en pointillé. Tasser les
/// barres saisies les unes contre les autres ferait lire quatre nuits comme une
/// semaine complète — et masquerait précisément ce qu'il faut corriger.
///
/// ## L'échelle ne part pas de la plus haute barre
///
/// Elle a un plancher à 10 h ([SleepWeek.scaleMinutes]). Une semaine de
/// courtes nuits mise à l'échelle de sa propre meilleure nuit afficherait des
/// barres pleine hauteur et donnerait l'impression d'un sans-faute.
class SleepBarChart extends StatelessWidget {
  final SleepWeek week;

  /// Jour actuellement mis en avant, ou null. Piloté par l'écran pour que la
  /// fiche de détail sous le graphique reste synchronisée avec la barre.
  final DateTime? selectedDate;

  final ValueChanged<SleepDay> onSelect;

  const SleepBarChart({
    super.key,
    required this.week,
    required this.onSelect,
    this.selectedDate,
  });

  /// Hauteur totale du bloc de tracé, étiquettes de valeur comprises.
  static const double _plotHeight = 168;

  /// Hauteur réservée à l'étiquette de valeur posée au-dessus de chaque barre.
  ///
  /// Elle est **toujours** réservée, même quand aucune barre n'est
  /// sélectionnée et qu'aucune étiquette n'est visible. Deux raisons :
  ///
  /// - **sans réservation, la colonne déborde.** Une barre qui atteint
  ///   l'échelle occupe toute la hauteur de tracé ; ajouter l'étiquette
  ///   au-dessus demandait une quinzaine de pixels de plus que la boîte n'en
  ///   avait — d'où le débordement par le bas ;
  /// - **la réserver en permanence évite que le graphique bouge.** Si l'espace
  ///   n'apparaissait qu'à la sélection, toutes les barres se tasseraient d'un
  ///   cran à chaque tap, et l'histogramme sauterait à chaque changement de
  ///   jour sélectionné.
  static const double _valueLabelHeight = 16;

  /// La hauteur réellement disponible pour les barres.
  static const double _barAreaHeight = _plotHeight - _valueLabelHeight;

  @override
  Widget build(BuildContext context) {
    final scale = week.scaleMinutes;

    return Column(
      children: [
        SizedBox(
          height: _plotHeight,
          child: Stack(
            children: [
              // Les repères (zone idéale + seuil minimum), derrière les
              // barres — des indications, pas des objets.
              //
              // Ils sont décalés du même espace d'étiquette que les barres :
              // les deux DOIVENT partager exactement la même zone de tracé,
              // sans quoi ni la bande « 7–9 h » ni le trait des 6 h ne
              // tomberaient à la bonne hauteur, et les repères deviendraient
              // des mensonges.
              Positioned(
                left: 0,
                right: 0,
                top: _valueLabelHeight,
                bottom: 0,
                child: _ChartGuides(scaleMinutes: scale),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in week.days)
                    Expanded(
                      child: _Bar(
                        day: day,
                        scaleMinutes: scale,
                        barAreaHeight: _barAreaHeight,
                        labelHeight: _valueLabelHeight,
                        selected:
                            selectedDate != null &&
                            _isSameDay(day.date, selectedDate!),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSelect(day);
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final day in week.days)
              Expanded(
                child: _DayLabel(
                  day: day,
                  selected:
                      selectedDate != null &&
                      _isSameDay(day.date, selectedDate!),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        const _ChartLegend(),
      ],
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Les repères posés derrière les barres : la zone idéale et le seuil minimum.
///
/// ## Deux repères, deux formes
///
/// - **La zone idéale** est une *bande remplie* : c'est un intervalle où l'on
///   veut se trouver, et une surface dit « viens là-dedans ».
/// - **Le minimum** est un *trait discontinu* : c'est une limite qu'on ne veut
///   pas franchir, et une ligne dit « ne descends pas sous moi ».
///
/// Leur donner la même forme les aurait rendus interchangeables à l'œil, alors
/// qu'ils ne demandent pas la même chose. Le pointillé porte aussi le sens
/// habituel d'un seuil, là où un trait plein se lirait comme un axe.
///
/// ## Où tombe le minimum, et pourquoi là
///
/// À **6 h**, parce que c'est exactement la frontière que le serveur utilise
/// pour classer une nuit : en dessous, `SleepAdvisor` la range en
/// `INSUFFISANT` ou `CRITIQUE`. Placer le trait ailleurs — à 5 h, à 6 h 30 —
/// aurait produit un graphique qui contredit le conseil affiché juste en
/// dessous.
class _ChartGuides extends StatelessWidget {
  final int scaleMinutes;

  const _ChartGuides({required this.scaleMinutes});

  static const int _idealMin = 420; // 7 h
  static const int _idealMax = 540; // 9 h

  /// Seuil sous lequel la nuit est déclarée insuffisante — même valeur que
  /// `SleepAdvisor.INSUFFISANT_MAX` côté serveur.
  static const int _minimum = 360; // 6 h

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final bottom = height * (_idealMin / scaleMinutes);
        final top = height * (_idealMax / scaleMinutes);
        final minimum = height * (_minimum / scaleMinutes);

        // AUCUN texte dans le tracé — voir _ChartLegend. Quel que soit
        // l'endroit choisi, une étiquette posée ici finit par se superposer à
        // la valeur d'une barre : au bord haut elle percute les nuits proches
        // de 9 h, au centre celles qui atteignent la cible, en bas les nuits
        // courtes. La zone de tracé ne contient donc que des repères muets.
        // Le Stack reste nécessaire : `Positioned` n'a de sens que dedans, et
        // c'est lui qui permet de caler les repères sur des minutes plutôt que
        // sur une fraction de la boîte.
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: bottom,
              height: (top - bottom).clamp(0.0, height),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.09),
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: AppColors.success.withValues(alpha: 0.28),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: minimum.clamp(0.0, height),
              child: const _DashedLine(),
            ),
          ],
        );
      },
    );
  }
}

/// Un trait discontinu pleine largeur.
///
/// Dessiné avec des segments plutôt qu'avec un `CustomPainter` : le besoin
/// tient en six lignes, et un peintre imposerait de gérer soi-même le
/// repaint. Le nombre de segments est calculé à la largeur disponible, donc
/// le pointillé reste régulier quelle que soit la taille de l'écran.
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  static const double _dashWidth = 4;
  static const double _gapWidth = 4;
  static const double _thickness = 1.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / (_dashWidth + _gapWidth))
            .floor()
            .clamp(1, 200);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: _dashWidth,
              height: _thickness,
              color: AppColors.error.withValues(alpha: 0.55),
            ),
          ),
        );
      },
    );
  }
}

/// La légende des repères, **sous** le graphique.
///
/// ## Pourquoi une légende et plus une étiquette dans le tracé
///
/// Le libellé « Zone idéale 7–9 h » était posé au bord haut de la bande. Il y
/// percutait la valeur affichée au-dessus d'une barre proche de 9 h — et aucun
/// autre emplacement à l'intérieur du tracé n'aurait été meilleur : au centre
/// il passait derrière les barres qui atteignent la cible, en bas derrière les
/// nuits courtes. Un tracé n'a que sept colonnes de large, tout texte qu'on y
/// pose finit sur une donnée.
///
/// La légende règle le problème en changeant de registre : chaque échantillon
/// **est** le repère, en réduction. On n'a plus besoin d'écrire sur le
/// graphique pour dire ce qu'il contient — et ajouter un second repère n'a
/// coûté qu'une ligne de plus, là où il aurait fallu retrouver une place libre
/// dans le tracé.
///
/// Un `Wrap` et non un `Row` : à deux entrées, une ligne unique déborde sur un
/// écran étroit ou avec une police agrandie.
class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 6,
      children: [
        // Le même remplissage et les mêmes liserés que la bande du tracé, en
        // miniature : c'est ce qui fait le lien sans un mot d'explication.
        _LegendItem(
          label: 'Zone idéale : 7 h – 9 h',
          sample: Container(
            width: 18,
            height: 11,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(2),
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: AppColors.success.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ),
        // Le pointillé, repris tel quel : c'est la forme qui distingue un
        // seuil d'un intervalle, elle doit se retrouver dans la légende.
        _LegendItem(
          label: 'Minimum : 6 h',
          sample: SizedBox(
            width: 18,
            height: 11,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  3,
                  (_) => Container(
                    width: 4,
                    height: 1.5,
                    color: AppColors.error.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Un échantillon et son libellé.
class _LegendItem extends StatelessWidget {
  final Widget sample;
  final String label;

  const _LegendItem({required this.sample, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        sample,
        const SizedBox(width: 7),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 10,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }
}

/// Une barre — ou une colonne creuse quand la nuit n'a pas été saisie.
class _Bar extends StatelessWidget {
  final SleepDay day;
  final int scaleMinutes;

  /// Hauteur disponible pour la barre seule, étiquette de valeur exclue.
  final double barAreaHeight;

  /// Espace réservé au-dessus de la barre pour l'étiquette de valeur.
  final double labelHeight;

  final bool selected;
  final VoidCallback onTap;

  const _Bar({
    required this.day,
    required this.scaleMinutes,
    required this.barAreaHeight,
    required this.labelHeight,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = day.durationMinutes;
    final color = day.band?.color ?? AppColors.textDisabled;

    // La barre est dimensionnée sur la zone de tracé SEULE, hors étiquette.
    // La mesurer sur la hauteur totale la faisait déborder par le bas dès
    // qu'elle approchait l'échelle : la colonne réclamait alors la hauteur de
    // la barre PLUS celle de l'étiquette posée au-dessus.
    //
    // Hauteur minimale de 6 px pour une nuit très courte : une barre de 2 px
    // ne se distingue pas d'une colonne vide, et c'est justement la nuit qu'il
    // faut voir.
    final ratio = minutes == null
        ? 0.0
        : (minutes / scaleMinutes).clamp(0.0, 1.0);
    final barHeight = minutes == null
        ? 0.0
        : (barAreaHeight * ratio).clamp(6.0, barAreaHeight);

    return Semantics(
      button: true,
      selected: selected,
      label: minutes == null
          ? '${day.dayLabel} : aucune nuit enregistrée'
          : '${day.dayLabel} : ${formatDuration(minutes)}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Boîte de hauteur FIXE, occupée ou non. Si elle n'apparaissait
              // qu'à la sélection, toutes les barres se tasseraient d'un cran
              // à chaque tap et l'histogramme sauterait à chaque changement de
              // jour sélectionné.
              SizedBox(
                height: labelHeight,
                child: minutes == null
                    ? null
                    : Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: selected ? 1 : 0,
                          child: FittedBox(
                            // Le texte rétrécit au lieu de déborder quand la
                            // colonne est étroite (sept jours sur un petit
                            // écran) ou que la police système est agrandie.
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formatDuration(minutes),
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 9,
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              if (minutes == null)
                // La colonne creuse : un socle en pointillé qui tient la place
                // sans prétendre à une valeur.
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.textDisabled.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                )
              else
                AnimatedContainer(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  height: barHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color,
                        color.withValues(alpha: selected ? 0.55 : 0.35),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(7),
                      bottom: Radius.circular(3),
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.55),
                              blurRadius: 14,
                              spreadRadius: -2,
                            ),
                          ]
                        : null,
                    border: selected
                        ? Border.all(
                            color: color.withValues(alpha: 0.9),
                            width: 1.4,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  final SleepDay day;
  final bool selected;

  const _DayLabel({required this.day, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: selected
            ? AppColors.primary.withValues(alpha: 0.18)
            : Colors.transparent,
      ),
      child: Text(
        day.initial,
        textAlign: TextAlign.center,
        style: AppTextStyles.labelSmall.copyWith(
          color: selected ? AppColors.primaryText : AppColors.textHint,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}
