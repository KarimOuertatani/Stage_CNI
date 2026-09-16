import 'package:flutter_test/flutter_test.dart';

import 'package:fitforge_app/core/theme/app_colors.dart';
import 'package:fitforge_app/features/workout/data/muscle_catalog_3d.dart';
import 'package:fitforge_app/features/workout/data/muscle_effort.dart';
import 'package:fitforge_app/features/workout/data/workout_model.dart';
import 'package:fitforge_app/features/workout/presentation/widgets/muscle_group_3d_mapper.dart';

/// Verrouille le contrat entre `fitforge_body.glb` et la couche Dart qui le
/// colore. Le catalogue étant généré (`scripts/gen_muscle_catalog_3d.py`), ces
/// tests sont le garde-fou d'une régénération : un nom de groupe qui dérive ou
/// un muscle absent du modèle casserait la coloration **en silence** côté
/// natif, le plugin ignorant sans bruit un override dont le nom ne matche
/// aucune entité.
void main() {
  final allNodes = kAllMuscleNodes3D.toSet();
  final appGroups = MuscleIntensity.mockData().map((mi) => mi.group).toSet();

  group('catalogue anatomique', () {
    test('le modèle expose bien ses 466 entités, sans doublon', () {
      // 464 muscles + les 2 aponévroses épicrâniennes.
      expect(kAllMuscleNodes3D, hasLength(466));
      expect(allNodes, hasLength(kAllMuscleNodes3D.length));
    });

    test('chaque noeud du modèle est résolu par le catalogue', () {
      final unresolved = kAllMuscleNodes3D.where(
        (name) => muscle3DFor(name) == null,
      );
      expect(unresolved, isEmpty);
    });

    test('chaque muscle porte un nom français non vide', () {
      for (final muscle in kMuscleCatalog3D.values) {
        expect(muscle.name.trim(), isNotEmpty);
        expect(muscle.region.trim(), isNotEmpty);
      }
    });
  });

  group('heatmap', () {
    test('les groupes colorés sont ceux de l\'app', () {
      expect(kHeatmapNodesByGroup.keys.toSet(), equals(appGroups));
      expect(revealOrder3D.toSet(), equals(appGroups));
    });

    test('chaque noeud coloré existe dans le modèle', () {
      for (final entry in kHeatmapNodesByGroup.entries) {
        expect(entry.value, isNotEmpty, reason: entry.key);
        for (final name in entry.value) {
          expect(allNodes, contains(name), reason: '${entry.key} → $name');
        }
      }
    });

    test('un muscle coloré appartient à son groupe et est superficiel', () {
      for (final entry in kHeatmapNodesByGroup.entries) {
        for (final name in entry.value) {
          final muscle = muscle3DFor(name)!;
          expect(muscle.group, entry.key, reason: name);
          expect(muscle.superficial, isTrue, reason: name);
        }
      }
    });

    test('aucun muscle n\'est colorable par deux groupes à la fois', () {
      final seen = <String>{};
      for (final names in kHeatmapNodesByGroup.values) {
        for (final name in names) {
          expect(seen.add(name), isTrue, reason: '$name est dans 2 groupes');
        }
      }
    });

    test('les groupes rattachés n\'utilisent que les noms de l\'app', () {
      final groups = kMuscleCatalog3D.values
          .map((m) => m.group)
          .whereType<String>()
          .toSet();
      expect(groups.difference(appGroups), isEmpty);
    });
  });

  group('résolution d\'un muscle touché', () {
    test('nom français, côté et groupe pour un muscle entraîné', () {
      const node = 'long_head_of_biceps_brachii_r';
      expect(muscle3DFor(node)!.group, 'Bras');
      expect(side3DFor(node), 'droite');
      expect(frenchNameFor3D(node), contains('Biceps brachial'));
      expect(frenchNameFor3D(node), contains('droite'));
      expect(groupLabelFor3D(node), 'Bras');
    });

    test('un muscle hors entraînement retombe sur sa région', () {
      const node = 'zygomaticus_major_muscle_l';
      expect(muscle3DFor(node)!.group, isNull);
      expect(groupLabelFor3D(node), 'Visage');
      expect(intensityForObject3D(node, MuscleEffort.empty), 0.0);
    });

    test('les suffixes d\'export .001 et _2 sont absorbés', () {
      expect(muscle3DFor('frontalis_muscle_l.001')!.name, 'Frontal');
      expect(muscle3DFor('temporalis_muscle_r_2')!.name, 'Temporal');
      expect(side3DFor('temporalis_muscle_r_2'), 'droite');
    });

    test('les deux conventions de côté sont reconnues', () {
      // Les muscles suffixent en `_l` / `_r`, les aponévroses en `.l` / `.r`.
      expect(side3DFor('gluteus_maximus_muscle_l'), 'gauche');
      expect(muscle3DFor('Epicranial aponeurosis.r')!.name, contains('poné'));
      expect(side3DFor('Epicranial aponeurosis.r'), 'droite');
      expect(groupLabelFor3D('Epicranial aponeurosis.l'), 'Crâne');
    });

    test('un muscle médian n\'a pas de côté', () {
      expect(side3DFor('diaphragm'), isNull);
      expect(frenchNameFor3D('diaphragm'), 'Diaphragme');
    });

    test('un noeud inconnu ne fait pas planter la fiche', () {
      expect(muscle3DFor('inexistant'), isNull);
      expect(frenchNameFor3D('inexistant'), 'inexistant');
      expect(groupLabelFor3D('inexistant'), '—');
    });
  });

  group('effort par muscle', () {
    /// Raccourci : [n] séries d'un exercice décrit par ses muscles ExerciseDB.
    MuscleEffort effortOf(
      int sets, {
      String? target,
      String? secondary,
      String? primary,
    }) {
      final builder = MuscleEffortBuilder();
      for (var i = 0; i < sets; i++) {
        builder.addSet(
          targetMuscles: target,
          secondaryMuscles: secondary,
          primaryMuscle: primary,
        );
      }
      return builder.build();
    }

    test('un exercice de biceps ne réveille pas tout le bras', () {
      // C'est le défaut que la granularité par groupe produisait : un curl
      // teintait biceps, triceps ET avant-bras d'un seul bloc.
      final effort = effortOf(
        6,
        target: 'BICEPS BRACHII',
        secondary: 'BRACHIALIS, BRACHIORADIALIS',
      );
      expect(effort.intensityOf('long_head_of_biceps_brachii'), 6 / 15);
      expect(effort.intensityOf('short_head_of_biceps_brachii'), 6 / 15);
      // Secondaires : présents, mais nettement moins chauds.
      expect(effort.intensityOf('brachialis_muscle'), lessThan(6 / 15));
      expect(effort.intensityOf('brachialis_muscle'), greaterThan(0));
      // Le triceps n'est pas sollicité : il doit rester froid.
      expect(effort.intensityOf('long_head_of_triceps_brachii'), 0.0);
      expect(effort.intensityOf('lateral_head_of_triceps_brachii'), 0.0);
    });

    test('un exercice de quadriceps n\'allume ni ischios ni fessiers', () {
      final effort = effortOf(5, target: 'QUADRICEPS');
      for (final quad in [
        'rectus_femoris_muscle',
        'vastus_lateralis_muscle',
        'vastus_medialis_muscle',
        'vastus_intermedius_muscle',
      ]) {
        // Les 4 chefs prennent la série entière, elle n'est pas divisée.
        expect(effort.intensityOf(quad), 5 / 15, reason: quad);
      }
      expect(effort.intensityOf('long_head_of_biceps_femoris'), 0.0);
      expect(effort.intensityOf('semitendinosus_muscle'), 0.0);
      expect(effort.intensityOf('gluteus_maximus_muscle'), 0.0);
      expect(effort.intensityOf('medial_head_of_gastrocnemius'), 0.0);
    });

    test('le muscle cible chauffe plus que les secondaires', () {
      // Curl marteau, tel qu'ExerciseDB le décrit réellement.
      final effort = effortOf(
        4,
        target: 'BRACHIORADIALIS',
        secondary: 'BICEPS BRACHII, BRACHIALIS',
      );
      final brachioradial = effort.intensityOf('brachioradialis_muscle');
      final biceps = effort.intensityOf('long_head_of_biceps_brachii');
      expect(brachioradial, greaterThan(biceps));
      expect(biceps, greaterThan(0));
    });

    test('l\'intensité sature à 1.0 et jamais au-delà', () {
      final effort = effortOf(40, target: 'RECTUS ABDOMINIS');
      expect(effort.intensityOf('rectus_abdominis_muscle'), 1.0);
      expect(effort.peakIntensity, 1.0);
    });

    test('sans données ExerciseDB, on retombe sur le groupe backend', () {
      final effort = effortOf(3, primary: 'PECTORAUX');
      expect(
        effort.intensityOf('sternocostal_head_of_pectoralis_major_muscle'),
        greaterThan(0),
      );
      // Repli volontairement grossier, mais borné au groupe concerné.
      expect(effort.intensityOf('rectus_femoris_muscle'), 0.0);
    });

    test('le cardio ne colore rien', () {
      final effort = effortOf(10, primary: 'CARDIO');
      expect(effort.isEmpty, isTrue);
      expect(effort.peakIntensity, 0.0);
    });

    test('un muscle ExerciseDB inconnu est ignoré sans planter', () {
      final effort = effortOf(3, target: 'MUSCLE IMAGINAIRE');
      expect(effort.isEmpty, isTrue);
    });

    test('tout le vocabulaire ExerciseDB vise des muscles du catalogue', () {
      for (final entry in kExerciseDbMuscleMap.entries) {
        expect(entry.value, isNotEmpty, reason: entry.key);
        for (final base in entry.value) {
          expect(
            kMuscleCatalog3D.containsKey(base),
            isTrue,
            reason: '${entry.key} → $base',
          );
        }
      }
    });
  });

  group('couleurs', () {
    test('un corps au repos vaut exactement le ton neutre', () {
      final colors = buildMuscle3DColorMap(MuscleEffort.empty);
      expect(colors, hasLength(kHeatmapNodesTopDown.length));
      for (final color in colors.values) {
        expect(color, AppColors.muscleNone);
      }
    });

    test('seuls les muscles sollicités quittent le neutre', () {
      final builder = MuscleEffortBuilder();
      builder.addSet(targetMuscles: 'BICEPS BRACHII');
      final colors = buildMuscle3DColorMap(builder.build());
      final chauds = colors.entries
          .where((e) => e.value != AppColors.muscleNone)
          .map((e) => e.key)
          .toSet();
      expect(chauds, isNotEmpty);
      for (final node in chauds) {
        expect(muscle3DFor(node)!.region, 'Biceps', reason: node);
      }
    });

    test('la heatmap monte du neutre au rouge profond', () {
      expect(colorFromIntensitySmooth(0), AppColors.muscleNone);
      expect(colorFromIntensitySmooth(1), AppColors.muscleMax);
      expect(colorFromIntensitySmooth(0.3), AppColors.muscleLow);
    });

    test('le ton de repos reste proche du neutre et varie par muscle', () {
      final tones = kAllMuscleNodes3D.map(restingColorFor3D).toSet();
      // Le jitter déterministe doit produire plusieurs teintes distinctes…
      expect(tones.length, greaterThan(10));
      // …sans jamais s'éloigner du neutre au point de se voir.
      for (final name in kAllMuscleNodes3D) {
        final tone = restingColorFor3D(name);
        expect((tone.r - AppColors.muscleNone.r).abs(), lessThan(0.1));
        expect((tone.g - AppColors.muscleNone.g).abs(), lessThan(0.1));
        expect((tone.b - AppColors.muscleNone.b).abs(), lessThan(0.1));
        expect(tone.a, 1.0);
      }
    });

    test('rgba et émissif restent dans les bornes attendues', () {
      final rgba = colorToRgba(AppColors.muscleMax);
      expect(rgba, hasLength(4));
      expect(rgba.every((v) => v >= 0.0 && v <= 1.0), isTrue);
      expect(colorToEmissive(AppColors.muscleMax, 0.0), [0.0, 0.0, 0.0]);
    });
  });
}
