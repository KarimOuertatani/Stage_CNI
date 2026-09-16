import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sleep_models.dart';

/// Mémoire du « on a déjà demandé aujourd'hui ».
///
/// ## Pourquoi le serveur ne suffit pas
///
/// Le serveur sait si la nuit du jour est **enregistrée**. Il ne sait pas si
/// l'adhérent a **choisi de passer**. Les deux mènent pourtant au même
/// résultat : on ne redemande pas.
///
/// Sans cette mémoire, quelqu'un qui appuie sur « Plus tard » reverrait le
/// pop-up à chaque retour sur l'accueil — c'est-à-dire dix fois par jour. Un
/// rappel qu'on ne peut pas faire taire cesse d'être un rappel et devient une
/// raison de désinstaller.
///
/// ## Pourquoi une date et pas un booléen
///
/// Un booléen « déjà demandé » resterait vrai pour toujours. En stockant la
/// **date** de la dernière demande, la comparaison avec aujourd'hui suffit :
/// le pop-up revient de lui-même le lendemain, sans qu'on ait à le remettre à
/// zéro à minuit — ce qui supposerait que l'application tourne à minuit.
///
/// ## Pourquoi `flutter_secure_storage`
///
/// Ce n'est pas un secret, et le chiffrement est inutile ici. C'est simplement
/// le seul stockage persistant déjà présent dans le projet (il porte le JWT) :
/// ajouter une dépendance pour mémoriser une date serait disproportionné.
class SleepPromptStore {
  SleepPromptStore._();

  static final SleepPromptStore instance = SleepPromptStore._();

  static const _key = 'fitforge_sleep_prompt_date';

  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  /// Copie mémoire : la question est posée à chaque construction de l'accueil,
  /// on ne relit pas le disque à chaque fois.
  String? _cache;
  bool _loaded = false;

  /// Vrai si le pop-up a déjà été proposé aujourd'hui (enregistré ou passé).
  Future<bool> askedToday() async {
    final today = formatIsoDate(DateTime.now());
    if (_loaded) return _cache == today;
    try {
      _cache = await _secure.read(key: _key);
    } catch (_) {
      // Stockage indisponible : on préfère poser la question une fois de trop
      // que de ne jamais la poser. Une fonctionnalité muette est pire qu'une
      // fonctionnalité insistante.
      _cache = null;
    }
    _loaded = true;
    return _cache == today;
  }

  /// Note qu'on a posé la question aujourd'hui — que la nuit ait été
  /// enregistrée ou que l'adhérent ait choisi de passer.
  Future<void> markAskedToday() async {
    final today = formatIsoDate(DateTime.now());
    _cache = today;
    _loaded = true;
    try {
      await _secure.write(key: _key, value: today);
    } catch (_) {
      // Échec d'écriture : la copie mémoire tient pour la session courante,
      // ce qui couvre déjà le cas gênant (le pop-up qui revient dix fois).
    }
  }

  /// Efface la mémoire — utilisé à la déconnexion : le compte suivant sur le
  /// même appareil doit se voir poser la question.
  Future<void> clear() async {
    _cache = null;
    _loaded = false;
    try {
      await _secure.delete(key: _key);
    } catch (_) {
      // Sans conséquence : `_loaded = false` force une relecture, et une
      // lecture qui échoue renvoie « jamais demandé ».
    }
  }
}
