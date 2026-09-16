// ignore: implementation_imports, unnecessary_import
import 'package:flutter_body_atlas/src/models/muscle.dart';
// ignore: unnecessary_import
import 'package:flutter_body_atlas/flutter_body_atlas.dart';
import '../../data/workout_model.dart';

/// Utilitaires de correspondance et traduction pour l'intégration de flutter_body_atlas.
abstract final class MuscleGroupMapper {
  /// Traduit un groupe musculaire du package en nom français de l'application.
  static String getFrenchGroupName(MuscleGroup group) {
    switch (group) {
      case MuscleGroup.chest:
        return 'Pectoraux';
      case MuscleGroup.back:
        return 'Dos';
      case MuscleGroup.shoulders:
        return 'Épaules';
      case MuscleGroup.arms:
        return 'Bras';
      case MuscleGroup.core:
        return 'Abdominaux';
      case MuscleGroup.legs:
      case MuscleGroup.hamstrings:
      case MuscleGroup.glutes:
      case MuscleGroup.adductors:
        return 'Jambes';
      case MuscleGroup.neck:
        return 'Cou';
    }
  }

  /// Récupère le nom du groupe français correspondant pour une info de muscle.
  static String getFrenchGroupForMuscle(MuscleInfo muscleInfo) {
    return getFrenchGroupName(muscleInfo.group);
  }

  /// Calcule l'intensité d'un muscle individuel à partir de la liste des intensités
  /// de son groupe parent dans l'application.
  static double getMuscleIntensity(
    MuscleInfo muscleInfo,
    List<MuscleIntensity> intensities,
  ) {
    if (intensities.isEmpty) return 0.0;

    final frenchGroup = getFrenchGroupForMuscle(muscleInfo);
    for (final mi in intensities) {
      if (mi.group.toLowerCase() == frenchGroup.toLowerCase()) {
        return mi.intensity;
      }
    }
    return 0.0;
  }

  /// Traduit le nom d'un muscle individuel en français avec gestion de la latéralité.
  static String getFrenchMuscleName(MuscleInfo info) {
    final baseName = _getBaseFrenchMuscleName(info.muscle);
    switch (info.side) {
      case BodySide.left:
        return '$baseName (Gauche)';
      case BodySide.right:
        return '$baseName (Droit)';
      case BodySide.none:
        return baseName;
    }
  }

  /// Traduction brute du muscle de l'anglais vers le français.
  static String _getBaseFrenchMuscleName(Muscle muscle) {
    switch (muscle) {
      case Muscle.semimembranosus2Right:
      case Muscle.semimembranosus2Left:
      case Muscle.semimembranosus1Right:
      case Muscle.semimembranosus1Left:
        return 'Demi-membraneux';
      case Muscle.semitendinosusRight:
      case Muscle.semitendinosusLeft:
        return 'Demi-tendineux';
      case Muscle.bicepsFemorisLeft:
      case Muscle.bicepsFemorisRight:
        return 'Biceps fémoral';
      case Muscle.iliotibialTractRight:
      case Muscle.iliotibialTractLeft:
        return 'Bandelette ilio-tibiale';
      case Muscle.gastrocnemiusRight:
      case Muscle.gastrocnemiusLeft:
        return 'Mollet (Gastrocnémien)';
      case Muscle.tibialisAnteriorLeft:
      case Muscle.tibialisAnteriorRight:
        return 'Tibial antérieur';
      case Muscle.extensorHallucisLongusLeft:
      case Muscle.extensorHallucisLongusRight:
        return 'Long extenseur de l\'hallux';
      case Muscle.fibularisLongusLeft:
      case Muscle.fibularisLongusRight:
        return 'Long fibulaire';
      case Muscle.extensorDigitorumLongusLeft:
      case Muscle.extensorDigitorumLongusRight:
        return 'Long extenseur des orteils';
      case Muscle.vastusLateralisLeft:
      case Muscle.vastusLateralisRight:
        return 'Vaste latéral (Quadriceps)';
      case Muscle.vastusMedialisLeft:
      case Muscle.vastusMedialisRight:
        return 'Vaste médial (Quadriceps)';
      case Muscle.sartorisLeft:
      case Muscle.sartorisRight:
        return 'Sartorius';
      case Muscle.gracilisLeft:
      case Muscle.gracilisRight:
        return 'Droit interne (Gracile)';
      case Muscle.rectusFemorisLeft:
      case Muscle.rectusFemorisRight:
        return 'Droit fémoral (Quadriceps)';
      case Muscle.gluteusMedius2Right:
      case Muscle.gluteusMedius2Left:
      case Muscle.gluteusMedius1Right:
      case Muscle.gluteusMedius1Left:
        return 'Moyen fessier';
      case Muscle.gluteusMaximusRight:
      case Muscle.gluteusMaximusLeft:
        return 'Grand fessier';
      case Muscle.externalObliqueRight:
      case Muscle.externalObliqueLeft:
      case Muscle.externalOblique1Left:
      case Muscle.externalOblique1Right:
      case Muscle.externalOblique2Left:
      case Muscle.externalOblique2Right:
      case Muscle.externalOblique3Left:
      case Muscle.externalOblique3Right:
      case Muscle.externalOblique4Left:
      case Muscle.externalOblique4Right:
      case Muscle.externalOblique5Left:
      case Muscle.externalOblique5Right:
      case Muscle.externalOblique6Left:
      case Muscle.externalOblique6Right:
      case Muscle.externalOblique7Left:
      case Muscle.externalOblique7Right:
      case Muscle.externalOblique8Left:
      case Muscle.externalOblique8Right:
        return 'Oblique externe';
      case Muscle.rectusAbdominis1:
      case Muscle.rectusAbdominis2Left:
      case Muscle.rectusAbdominis2Right:
      case Muscle.rectusAbdominis3Left:
      case Muscle.rectusAbdominis3Right:
      case Muscle.rectusAbdominis4Left:
      case Muscle.rectusAbdominis4Right:
        return 'Grand droit de l\'abdomen';
      case Muscle.extensorDigitorumRight:
      case Muscle.extensorDigitorumLeft:
        return 'Extenseur des doigts';
      case Muscle.brachioradialisRight:
      case Muscle.brachioradialisLeft:
        return 'Brachioradial (Avant-bras)';
      case Muscle.extensorCarpiUlnarisRight:
      case Muscle.extensorCarpiUlnarisLeft:
        return 'Extenseur ulnaire du carpe';
      case Muscle.anconeusRight:
      case Muscle.anconeusLeft:
        return 'Anconé';
      case Muscle.flexorCarpiUlnarisRight:
      case Muscle.flexorCarpiUlnarisLeft:
        return 'Fléchisseur ulnaire du carpe';
      case Muscle.tricepsBrachiiCaputLateraleRight:
      case Muscle.tricepsBrachiiCaputLateraleLeft:
        return 'Triceps (Chef latéral)';
      case Muscle.tricepsBrachiiCaputLongumRight:
      case Muscle.tricepsBrachiiCaputLongumLeft:
        return 'Triceps (Chef long)';
      case Muscle.tricepsBrachiiCaputMedialeRight:
      case Muscle.tricepsBrachiiCaputMedialeLeft:
        return 'Triceps (Chef médial)';
      case Muscle.flexorDigitorumSuperficialisLeft:
      case Muscle.flexorDigitorumSuperficialisRight:
        return 'Fléchisseur superficiel des doigts';
      case Muscle.pronatorQuadratusLeft:
      case Muscle.pronatorQuadratusRight:
        return 'Carré pronateur';
      case Muscle.extensorCarpiRadialisLongusLeft:
      case Muscle.extensorCarpiRadialisLongusRight:
        return 'Long extenseur radial du carpe';
      case Muscle.palmarisLongusLeft:
      case Muscle.palmarisLongusRight:
        return 'Long palmaire';
      case Muscle.flexorCarpiRadialisLeft:
      case Muscle.flexorCarpiRadialisRight:
        return 'Fléchisseur radial du carpe';
      case Muscle.pronatorTeresLeft:
      case Muscle.pronatorTeresRight:
        return 'Rond pronateur';
      case Muscle.bicepsBrachiiCaputBreveLeft:
      case Muscle.bicepsBrachiiCaputBreveRight:
        return 'Biceps (Chef court)';
      case Muscle.bicepsBrachiiCaputLongumLeft:
      case Muscle.bicepsBrachiiCaputLongumRight:
        return 'Biceps (Chef long)';
      case Muscle.sternocleidomastoidRight:
      case Muscle.sternocleidomastoidLeft:
        return 'Sterno-cléido-mastoïdien';
      case Muscle.platysma:
        return 'Platysma (Cou)';
      case Muscle.sternohyoid:
        return 'Sterno-hyoïdien';
      case Muscle.infraspinatusRight:
      case Muscle.infraspinatusLeft:
        return 'Infra-épineux';
      case Muscle.latissimusDorsiRight:
      case Muscle.latissimusDorsiLeft:
        return 'Grand dorsal';
      case Muscle.lateralDeltoidRight:
      case Muscle.lateralDeltoidLeft:
        return 'Deltoïde latéral (Épaule)';
      case Muscle.posteriorDeltoidLeft:
      case Muscle.posteriorDeltoidRight:
        return 'Deltoïde postérieur (Épaule)';
      case Muscle.anteriorDeltoidLeft:
      case Muscle.anteriorDeltoidRight:
        return 'Deltoïde antérieur (Épaule)';
      case Muscle.trapeziusUpperLeft:
      case Muscle.trapeziusUpperRight:
        return 'Trapèze supérieur';
      case Muscle.trapeziusMiddleLeft:
      case Muscle.trapeziusMiddleRight:
        return 'Trapèze moyen';
      case Muscle.trapeziusLowerLeft:
      case Muscle.trapeziusLowerRight:
        return 'Trapèze inférieur';
      case Muscle.pectoralisMajorLeft:
      case Muscle.pectoralisMajorRight:
        return 'Grand pectoral';
      case Muscle.adductorMagnusLeft:
      case Muscle.adductorMagnusRight:
        return 'Grand adducteur';
      case Muscle.adductorLongusLeft:
      case Muscle.adductorLongusRight:
        return 'Long adducteur';
      case Muscle.pectineusLeft:
      case Muscle.pectineusRight:
        return 'Pectiné';
    }
  }
}
