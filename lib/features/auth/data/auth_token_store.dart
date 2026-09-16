import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage du token JWT.
///
/// Persisté **de façon chiffrée** sur l'appareil (Keystore Android / Keychain
/// iOS) via `flutter_secure_storage`, afin que l'utilisateur **reste connecté**
/// après fermeture/redémarrage de l'app. Une copie en mémoire (`_cache`) évite
/// de relire le disque à chaque requête HTTP (l'intercepteur Dio lit le token
/// avant chaque appel).
class AuthTokenStore {
  AuthTokenStore._();

  static final AuthTokenStore instance = AuthTokenStore._();

  static const _key = 'fitforge_jwt';

  // Chiffrement au repos géré par la lib (Keystore Android / Keychain iOS).
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  String? _cache;
  bool _loaded = false;

  /// Token déjà en mémoire, **sans lecture disque**, ou `null`.
  ///
  /// Sert aux rares endroits qui ont besoin du jeton de façon **synchrone** :
  /// typiquement `Image.network`, dont le paramètre `headers` ne peut pas être
  /// attendu. C'est le cas des justificatifs de candidature coach, qui ne sont
  /// pas servis publiquement sous `/media/**` et exigent donc une
  /// autorisation.
  ///
  /// ⚠️ Renvoie `null` tant que [read] n'a pas été appelé au moins une fois.
  /// En pratique ce n'est pas une limite : `AuthNotifier` appelle [read] au
  /// démarrage de l'application pour restaurer la session, donc tout écran
  /// atteint par un utilisateur connecté trouve le cache rempli. Ne PAS s'en
  /// servir comme source de vérité pour décider si quelqu'un est authentifié —
  /// c'est le rôle de [read].
  String? get cachedToken => _cache;

  /// Lit le token (mémoire si déjà chargé, sinon depuis le stockage chiffré).
  Future<String?> read() async {
    if (_loaded) return _cache;
    try {
      _cache = await _secure.read(key: _key);
    } catch (_) {
      // Stockage indisponible (ex : Keystore corrompu) → on repart propre.
      _cache = null;
    }
    _loaded = true;
    return _cache;
  }

  /// Enregistre le token en mémoire ET sur le disque chiffré.
  Future<void> write(String value) async {
    _cache = value;
    _loaded = true;
    await _secure.write(key: _key, value: value);
  }

  /// Efface le token (déconnexion / token invalide).
  Future<void> delete() async {
    _cache = null;
    _loaded = true;
    await _secure.delete(key: _key);
  }
}
