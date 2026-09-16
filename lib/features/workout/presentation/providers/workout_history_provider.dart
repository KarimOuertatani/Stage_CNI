import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/workout_api.dart';
import '../../data/workout_history_model.dart';
import 'workout_provider.dart' show workoutApiProvider;

class WorkoutHistoryState {
  final DateTime selectedDay;
  final List<WorkoutLogEntry> entries;
  final bool isLoading;
  final String? errorMessage;

  WorkoutHistoryState({
    DateTime? selectedDay,
    this.entries = const [],
    this.isLoading = false,
    this.errorMessage,
  }) : selectedDay = selectedDay ?? _today();

  bool get isToday => _sameDay(selectedDay, _today());

  /// Nombre total d'exercices distincts réalisés ce jour.
  int get totalExercises => entries.fold(0, (s, e) => s + e.exercises.length);

  /// Volume total soulevé ce jour (kg).
  double get totalVolume => entries.fold(0.0, (s, e) => s + e.totalVolume);

  int get totalSets => entries.fold(0, (s, e) => s + e.totalSets);

  WorkoutHistoryState copyWith({
    DateTime? selectedDay,
    List<WorkoutLogEntry>? entries,
    bool? isLoading,
    String? errorMessage,
  }) {
    return WorkoutHistoryState(
      selectedDay: selectedDay ?? this.selectedDay,
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class WorkoutHistoryNotifier extends Notifier<WorkoutHistoryState> {
  late final WorkoutApi _api = ref.read(workoutApiProvider);

  @override
  WorkoutHistoryState build() {
    Future.microtask(() => loadDay(_today()));
    return WorkoutHistoryState(isLoading: true);
  }

  Future<void> loadDay(DateTime day) async {
    final normalized = DateTime(day.year, day.month, day.day);
    state = state.copyWith(
      selectedDay: normalized,
      isLoading: true,
      errorMessage: null,
    );
    try {
      final entries = await _api.getLogsForDay(normalized);
      state = WorkoutHistoryState(
        selectedDay: normalized,
        entries: entries,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> previousDay() =>
      loadDay(state.selectedDay.subtract(const Duration(days: 1)));

  Future<void> nextDay() {
    if (state.isToday) return Future.value();
    return loadDay(state.selectedDay.add(const Duration(days: 1)));
  }

  Future<void> goToday() => loadDay(_today());
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

final workoutHistoryProvider =
    NotifierProvider<WorkoutHistoryNotifier, WorkoutHistoryState>(
      WorkoutHistoryNotifier.new,
    );
