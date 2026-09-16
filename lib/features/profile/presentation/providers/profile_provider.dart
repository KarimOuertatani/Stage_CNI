import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/profile_api.dart';
import '../../data/profile_model.dart';

class ProfileState {
  final ProfileModel? profile;
  final TrainingScoreModel? score;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  const ProfileState({
    this.profile,
    this.score,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  ProfileState copyWith({
    ProfileModel? profile,
    TrainingScoreModel? score,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      score: score ?? this.score,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
    );
  }
}

class ProfileNotifier extends Notifier<ProfileState> {
  late final ProfileApi _api = ref.read(profileApiProvider);

  @override
  ProfileState build() {
    Future.microtask(load);
    return const ProfileState(isLoading: true);
  }

  /// Charge le profil et le score courant.
  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final profile = await _api.getProfile();
      final score = await _api.getCurrentScore();
      state = ProfileState(profile: profile, score: score, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Met à jour le profil ; le backend recalcule âge/IMC/TDEE.
  Future<bool> updateProfile(Map<String, dynamic> fields) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final updated = await _api.updateProfile(fields);
      state = state.copyWith(profile: updated, isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Recalcule le score de la semaine.
  Future<void> recomputeScore() async {
    try {
      final score = await _api.recomputeScore();
      state = state.copyWith(score: score);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

final profileApiProvider = Provider<ProfileApi>(
  (ref) => ProfileApi(ref.read(dioClientProvider)),
);

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(
  ProfileNotifier.new,
);
