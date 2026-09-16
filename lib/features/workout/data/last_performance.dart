/// Ce que l'adhérent a fait la **dernière fois** sur un exercice.
///
/// Réponse de `GET /workout-logs/last?exerciseId=`. Sert deux choses dans
/// l'écran de saisie : le bandeau de rappel (« il y a 4 jours : 4×10 @ 32,5 kg »)
/// et le **pré-remplissage** des séries. Sans elle, l'écran proposait les mêmes
/// 4 × 10 à 20 kg à tout le monde, à chaque séance.
class LastPerformance {
  final DateTime performedOn;

  /// Nombre de jours écoulés, calculé par le serveur.
  final int daysAgo;

  final List<PerformedSet> sets;

  /// Charge la plus lourde de cette séance, si des charges ont été saisies.
  final double? bestWeightKg;

  /// Volume total (somme reps × charge) réalisé sur cet exercice ce jour-là.
  final double totalVolumeKg;

  const LastPerformance({
    required this.performedOn,
    required this.daysAgo,
    required this.sets,
    required this.bestWeightKg,
    required this.totalVolumeKg,
  });

  /// Résumé court affiché dans le bandeau : « 4 × 10 @ 32,5 kg ».
  ///
  /// On affiche la série la PLUS LOURDE et non une moyenne : c'est la référence
  /// que le pratiquant a en tête quand il charge la barre.
  String get summary {
    if (sets.isEmpty) return '—';
    final heaviest = sets.reduce(
      (a, b) => (b.weightKg ?? 0) > (a.weightKg ?? 0) ? b : a,
    );
    final reps = heaviest.reps ?? 0;
    final weight = heaviest.weightKg;
    final weightText = weight == null || weight == 0
        ? 'poids du corps'
        : '${_trim(weight)} kg';
    return '${sets.length} × $reps @ $weightText';
  }

  /// « aujourd'hui », « hier », « il y a 4 jours », « il y a 3 semaines ».
  String get whenLabel {
    if (daysAgo <= 0) return "aujourd'hui";
    if (daysAgo == 1) return 'hier';
    if (daysAgo < 14) return 'il y a $daysAgo jours';
    if (daysAgo < 60) return 'il y a ${(daysAgo / 7).round()} semaines';
    return 'il y a ${(daysAgo / 30).round()} mois';
  }

  static String _trim(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  factory LastPerformance.fromJson(Map<String, dynamic> json) {
    return LastPerformance(
      performedOn: DateTime.parse(json['performedOn'] as String),
      daysAgo: (json['daysAgo'] as num?)?.toInt() ?? 0,
      sets: ((json['sets'] as List<dynamic>?) ?? const [])
          .map((e) => PerformedSet.fromJson(e as Map<String, dynamic>))
          .toList(),
      bestWeightKg: (json['bestWeightKg'] as num?)?.toDouble(),
      totalVolumeKg: (json['totalVolumeKg'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Une série réellement réalisée lors de cette séance.
class PerformedSet {
  final int? setNumber;
  final int? reps;
  final double? weightKg;

  const PerformedSet({this.setNumber, this.reps, this.weightKg});

  factory PerformedSet.fromJson(Map<String, dynamic> json) {
    return PerformedSet(
      setNumber: (json['setNumber'] as num?)?.toInt(),
      reps: (json['reps'] as num?)?.toInt(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
    );
  }
}
