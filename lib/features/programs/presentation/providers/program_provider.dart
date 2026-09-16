import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/ai_program_models.dart';
import '../../data/program_api.dart';
import '../../data/program_models.dart';

/// État de la page « Programmes » : mes programmes + modèles prêts à l'emploi.
class ProgramsState {
  final List<ProgramModel> myPrograms;
  final List<ProgramModel> templates;
  final bool isLoading;
  final String? errorMessage;

  const ProgramsState({
    this.myPrograms = const [],
    this.templates = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ProgramsState copyWith({
    List<ProgramModel>? myPrograms,
    List<ProgramModel>? templates,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProgramsState(
      myPrograms: myPrograms ?? this.myPrograms,
      templates: templates ?? this.templates,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ProgramsNotifier extends Notifier<ProgramsState> {
  late final ProgramApi _api = ref.read(programApiProvider);

  @override
  ProgramsState build() {
    Future.microtask(loadAll);
    return const ProgramsState(isLoading: true);
  }

  /// Charge en parallèle mes programmes et les modèles.
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _api.getMyPrograms(),
        _api.getTemplates(),
      ]);
      state = ProgramsState(
        myPrograms: results[0],
        templates: results[1],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _msg(e));
    }
  }

  /// Crée un programme personnel et l'ajoute à la liste. Renvoie le programme créé.
  Future<ProgramModel> createProgram({
    required String title,
    String? description,
    String? goal,
    String? experienceLevel,
    int? durationWeeks,
  }) async {
    final created = await _api.createProgram(
      title: title,
      description: description,
      goal: goal,
      experienceLevel: experienceLevel,
      durationWeeks: durationWeeks,
    );
    upsertMyProgram(created);
    return created;
  }

  /// Génère un programme avec l'IA FitForge et l'ajoute à mes programmes.
  ///
  /// Le programme revient **déjà enregistré** par le serveur : il n'y a pas
  /// d'étape de confirmation. C'est un choix — l'adhérent vient de répondre à
  /// tout un questionnaire, lui demander une validation de plus sur un
  /// programme qu'il n'a pas encore ouvert n'apporte rien. Il l'ouvre, et il
  /// le modifie ou le supprime comme n'importe quel autre programme.
  Future<ProgramModel> generateAiProgram(
    AiProgramBrief brief, {
    CancelToken? cancelToken,
  }) async {
    final created = await _api.generateAiProgram(
      brief,
      cancelToken: cancelToken,
    );
    upsertMyProgram(created);
    return created;
  }

  /// Adopte un modèle (copie personnelle) et l'ajoute à mes programmes.
  Future<ProgramModel> adoptTemplate(String templateId) async {
    final copy = await _api.adoptTemplate(templateId);
    upsertMyProgram(copy);
    return copy;
  }

  /// Supprime un programme personnel.
  Future<void> deleteProgram(String id) async {
    await _api.deleteProgram(id);
    state = state.copyWith(
      myPrograms: state.myPrograms.where((p) => p.id != id).toList(),
    );
  }

  /// Insère ou remplace un programme dans « mes programmes » (après une
  /// mutation faite depuis l'écran de détail : ajout de séance/exercice…).
  void upsertMyProgram(ProgramModel program) {
    final list = [...state.myPrograms];
    final idx = list.indexWhere((p) => p.id == program.id);
    if (idx >= 0) {
      list[idx] = program;
    } else {
      list.add(program);
    }
    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    state = state.copyWith(myPrograms: list);
  }

  static String _msg(Object e) {
    final s = e.toString();
    return s.startsWith('ApiException') ? s.split(': ').last : s;
  }
}

final programApiProvider = Provider<ProgramApi>(
  (ref) => ProgramApi(ref.read(dioClientProvider)),
);

final programsProvider = NotifierProvider<ProgramsNotifier, ProgramsState>(
  ProgramsNotifier.new,
);
