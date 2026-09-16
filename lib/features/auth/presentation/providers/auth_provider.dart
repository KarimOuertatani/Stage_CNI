import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/session/session_reset.dart';
import '../../data/auth_api.dart';
import '../../data/auth_token_store.dart';
import '../../data/user_model.dart';
import '../../../sleep/data/sleep_prompt_store.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthenticated;

  /// Adresse d'un compte existant mais **non vérifié**, détectée lors d'une
  /// tentative de connexion. L'écran de connexion s'en sert pour renvoyer
  /// l'utilisateur vers la saisie du code plutôt que d'afficher une erreur
  /// sans issue.
  final String? pendingVerificationEmail;

  /// Vrai dès que la session du démarrage a été **tranchée** — jeton absent,
  /// jeton refusé, ou compte récupéré. À ne pas confondre avec
  /// [isAuthenticated] (le verdict) ni avec [isLoading] (qui repasse à vrai à
  /// chaque appel réseau ultérieur).
  ///
  /// Le splash s'en sert pour savoir quand il peut céder la main : tant que
  /// c'est faux, `isAuthenticated == false` ne veut pas dire « non connecté »,
  /// seulement « on ne sait pas encore ».
  final bool isBootstrapped;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isAuthenticated = false,
    this.pendingVerificationEmail,
    this.isBootstrapped = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    bool? isAuthenticated,
    String? pendingVerificationEmail,
    bool? isBootstrapped,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // réinitialisé si non fourni explicitement
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      // Comme errorMessage : réinitialisé à chaque nouvelle tentative.
      pendingVerificationEmail: pendingVerificationEmail,
      isBootstrapped: isBootstrapped ?? this.isBootstrapped,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  final AuthTokenStore _storage = AuthTokenStore.instance;
  late final AuthApi _authApi = ref.read(authApiProvider);

  @override
  AuthState build() {
    Future.microtask(_checkToken);
    return const AuthState(isLoading: true);
  }

  /// Au démarrage : s'il existe un token, on tente de récupérer le compte.
  Future<void> _checkToken() async {
    state = state.copyWith(isLoading: true);
    final token = await _storage.read();
    if (token == null) {
      state = const AuthState(isLoading: false, isBootstrapped: true);
      return;
    }
    try {
      final user = await _authApi.getMe();
      state = AuthState(
        user: user,
        isAuthenticated: true,
        isLoading: false,
        isBootstrapped: true,
      );
    } catch (_) {
      // Token invalide/expiré : on repart propre (écran de connexion).
      await _storage.delete();
      state = const AuthState(isLoading: false, isBootstrapped: true);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await _authApi.login(email: email, password: password);
      await _storage.write(token);
      final user = await _authApi.getMe();
      state = AuthState(
        user: user,
        isAuthenticated: true,
        isLoading: false,
        isBootstrapped: true,
      );
      return true;
    } catch (e) {
      // Compte existant mais email non vérifié : on mémorise l'adresse pour
      // que l'écran de connexion propose directement la saisie du code.
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageFrom(e),
        pendingVerificationEmail: isEmailNotVerified(e) ? email : null,
      );
      return false;
    }
  }

  Future<bool> signup(
    String fullName,
    String email,
    String password,
    DateTime birthDate, {
    String? phoneNumber,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _authApi.register(
        fullName: fullName,
        email: email,
        password: password,
        birthDate: birthDate,
        phoneNumber: phoneNumber,
      );
      // Pas de token à ce stade : le compte est créé désactivé. L'écran
      // d'inscription enchaîne sur la saisie du code reçu par email.
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _messageFrom(e));
      return false;
    }
  }

  /// Inscription en tant que COACH (renvoie true si succès).
  Future<bool> signupCoach(
    String fullName,
    String email,
    String password, {
    String? phoneNumber,
    String? headline,
    int? yearsExperience,
    List<String> specialties = const [],
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _authApi.registerCoach(
        fullName: fullName,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
        headline: headline,
        yearsExperience: yearsExperience,
        specialties: specialties,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _messageFrom(e));
      return false;
    }
  }

  /// Valide le code reçu par email : active le compte et connecte
  /// l'utilisateur dans la foulée (le backend renvoie le JWT).
  ///
  /// Renvoie `null` en cas de succès, sinon le message d'erreur à afficher
  /// (code incorrect, expiré, trop de tentatives…).
  Future<String?> verifyEmail(String email, String code) async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await _authApi.verifyEmail(email: email, code: code);
      await _storage.write(token);
      final user = await _authApi.getMe();
      state = AuthState(
        user: user,
        isAuthenticated: true,
        isLoading: false,
        isBootstrapped: true,
      );
      return null;
    } catch (e) {
      final message = _messageFrom(e);
      state = state.copyWith(isLoading: false, errorMessage: message);
      return message;
    }
  }

  /// Demande un nouveau code. Renvoie `null` si la demande est acceptée,
  /// sinon le message du backend (délai d'attente non écoulé, compte déjà
  /// vérifié…).
  Future<String?> resendCode(String email) async {
    try {
      await _authApi.resendCode(email);
      return null;
    } catch (e) {
      return _messageFrom(e);
    }
  }

  /// Vrai si l'erreur correspond à un compte non vérifié : l'app peut alors
  /// rediriger vers l'écran de saisie du code au lieu d'afficher une erreur.
  static bool isEmailNotVerified(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      return data is Map && data['code'] == 'EMAIL_NOT_VERIFIED';
    }
    return false;
  }

  /// Met à jour ma photo de profil. Rafraîchit l'utilisateur en mémoire pour
  /// que le nouvel avatar s'affiche partout (accueil, profil, chat…).
  Future<bool> updateAvatar(
    String path, {
    String? filename,
    String? contentType,
  }) async {
    try {
      final user = await _authApi.updateAvatar(
        path,
        filename: filename,
        contentType: contentType,
      );
      state = state.copyWith(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: _messageFrom(e));
      return false;
    }
  }

  /// Supprime ma photo de profil.
  Future<bool> removeAvatar() async {
    try {
      final user = await _authApi.removeAvatar();
      state = state.copyWith(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: _messageFrom(e));
      return false;
    }
  }

  /// Déconnexion : jeton effacé, mémoire de l'appareil nettoyée, **et caches
  /// vidés**.
  ///
  /// Le dernier point est le moins évident et le plus important. Le
  /// `ProviderScope` vit aussi longtemps que le processus, pas aussi longtemps
  /// qu'une session : sans [resetUserScopedProviders], le compte suivant sur le
  /// même appareil hérite en mémoire du profil, des repas, des programmes, des
  /// séances et des nuits du précédent. Effacer le jeton ne suffit pas — il
  /// empêche de **recharger** des données, pas d'**afficher** celles qui sont
  /// déjà là.
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _authApi.logout();
    await _storage.delete();
    // Le « déjà demandé aujourd'hui » du sommeil est mémorisé sur l'APPAREIL,
    // pas par compte. Sans cet effacement, quelqu'un qui se connecte après une
    // déconnexion hériterait du refus de l'utilisateur précédent et ne verrait
    // jamais le pop-up de sa journée.
    await SleepPromptStore.instance.clear();
    resetUserScopedProviders(ref);
    // `isBootstrapped` reste vrai : la session du démarrage a bien été
    // tranchée, on vient juste de la fermer. Le remettre à faux ferait croire
    // au splash — s'il était réaffiché — qu'il doit encore attendre le réseau.
    state = const AuthState(isBootstrapped: true);
  }

  /// Extrait un message lisible depuis une erreur Dio/ApiException.
  /// On privilégie le message métier renvoyé par le backend
  /// (ApiError.message), sinon le message générique de l'ApiException.
  String _messageFrom(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      final err = e.error;
      if (err is ApiException) return err.message;
      return e.message ?? 'Erreur réseau';
    }
    if (e is ApiException) return e.message;
    return e.toString().replaceAll('Exception: ', '');
  }
}

/// AuthApi câblé sur le client Dio (token JWT injecté automatiquement).
final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.read(dioClientProvider)),
);

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
