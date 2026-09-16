/// Présence d'un interlocuteur : est-il connecté, et sinon depuis quand ?
///
/// Deux origines, même forme :
/// - **REST** `GET /presence/{userId}` à l'ouverture d'un écran (état initial) ;
/// - **WebSocket** `/user/queue/presence` pour chaque changement ensuite.
///
/// Le backend n'envoie `lastSeenAt` que lorsque la personne est **hors ligne** :
/// quand elle est là, l'information n'aurait aucun sens.
class Presence {
  final String userId;
  final bool online;
  final DateTime? lastSeenAt;

  const Presence({required this.userId, required this.online, this.lastSeenAt});

  /// État par défaut avant toute réponse du serveur : on n'affirme rien.
  const Presence.unknown(this.userId) : online = false, lastSeenAt = null;

  factory Presence.fromJson(Map<String, dynamic> j) => Presence(
    userId: j['userId'] as String? ?? '',
    online: j['online'] as bool? ?? false,
    lastSeenAt: _parse(j['lastSeenAt']),
  );

  static DateTime? _parse(Object? v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v)?.toLocal();
  }

  /// Libellé affiché sous le nom de l'interlocuteur.
  ///
  /// Renvoie `null` quand on ne sait rien (jamais connecté, ou état pas encore
  /// reçu) : mieux vaut n'afficher aucune ligne qu'une information fausse.
  String? get label {
    if (online) return 'En ligne';

    final seen = lastSeenAt;
    if (seen == null) return null;

    final diff = DateTime.now().difference(seen);
    if (diff.isNegative || diff.inMinutes < 1) return 'Vu à l\'instant';
    if (diff.inMinutes < 60) return 'Vu il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return 'Vu il y a $h ${h == 1 ? 'heure' : 'heures'}';
    }

    final time = '${_two(seen.hour)}:${_two(seen.minute)}';
    if (diff.inDays == 1) return 'Vu hier à $time';
    if (diff.inDays < 7) return 'Vu ${_weekday(seen.weekday)} à $time';
    return 'Vu le ${_two(seen.day)}/${_two(seen.month)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _weekday(int weekday) => const [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ][weekday - 1];
}
