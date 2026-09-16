/// Partie du corps pour la navigation « Parcourir par zone ».
///
/// Mappé depuis le `BodyPartResponse` du backend :
/// { name, labelFr, imageUrl, exerciseCount }.
class BodyPartModel {
  /// Code ExerciseDB (CHEST, BACK, WAIST…), utilisé comme filtre serveur.
  final String name;

  /// Libellé affiché en français.
  final String labelFr;

  /// Illustration anatomique (CDN, .webp) — repli.
  final String? imageUrl;

  /// Photo représentative d'un exercice de la zone (.jpg) — image principale.
  final String? photoUrl;

  /// Nombre d'exercices rattachés à la zone.
  final int exerciseCount;

  const BodyPartModel({
    required this.name,
    required this.labelFr,
    this.imageUrl,
    this.photoUrl,
    required this.exerciseCount,
  });

  /// Meilleure image pour la carte : photo d'exercice (.jpg, décode partout)
  /// en priorité, sinon l'illustration.
  String? get displayImage =>
      (photoUrl != null && photoUrl!.isNotEmpty) ? photoUrl : imageUrl;

  factory BodyPartModel.fromJson(Map<String, dynamic> json) {
    return BodyPartModel(
      name: json['name'] as String? ?? '',
      labelFr: json['labelFr'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      photoUrl: json['photoUrl'] as String?,
      exerciseCount: (json['exerciseCount'] as num?)?.toInt() ?? 0,
    );
  }
}
