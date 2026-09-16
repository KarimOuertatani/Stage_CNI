import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../programs/presentation/screens/programs_view.dart';
import '../providers/active_session_provider.dart';
import 'exercise_library_view.dart';
import '../../../../core/widgets/screen_background.dart';

/// Onglet principal « Séances » : deux sous-onglets.
///  - **Programmes** : mes programmes + modèles prêts (Push/Pull/Legs…), avec
///    création de séances perso.
///  - **Exercices**  : la bibliothèque d'exercices du référentiel.
///
/// Une **barre de séance en cours** s'affiche en haut dès qu'au moins un
/// exercice a été ajouté : on y termine (ou abandonne) la séance complète.
class WorkoutHubScreen extends ConsumerWidget {
  const WorkoutHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Séances'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primaryText,
                unselectedLabelColor: AppColors.textHint,
                labelStyle: AppTextStyles.titleMedium,
                unselectedLabelStyle: AppTextStyles.titleMedium,
                tabs: const [
                  Tab(text: 'Programmes'),
                  Tab(text: 'Exercices'),
                ],
              ),
            ),
          ),
        ),
        body: ScreenBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (session.isActive)
                  _ActiveSessionBar(
                    session: session,
                    onOpen: () => _openSessionSheet(context, ref),
                  ),
                const Expanded(
                  child: TabBarView(
                    children: [ProgramsView(), ExerciseLibraryView()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSessionSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SessionSheet(),
    );
  }
}

// ── Barre « séance en cours » ─────────────────────────────────────────
class _ActiveSessionBar extends StatelessWidget {
  final ActiveSessionState session;
  final VoidCallback onOpen;

  const _ActiveSessionBar({required this.session, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.fitness_center_rounded,
                  color: AppColors.onGradient,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Séance en cours',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.onGradient,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${session.exerciseCount} exercice${session.exerciseCount > 1 ? 's' : ''} · ${session.totalSets} séries',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.onGradient,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.onGradient.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Terminer',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.onGradient,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: AppColors.onGradient,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Feuille de fin de séance ──────────────────────────────────────────
class _SessionSheet extends ConsumerStatefulWidget {
  const _SessionSheet();

  @override
  ConsumerState<_SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends ConsumerState<_SessionSheet> {
  bool _submitting = false;

  Future<void> _finish() async {
    setState(() => _submitting = true);
    final error = await ref.read(activeSessionProvider.notifier).finish();
    if (!mounted) return;
    setState(() => _submitting = false);

    Navigator.pop(context);
    final messenger = ScaffoldMessenger.of(context);
    if (error == null) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
            'Séance enregistrée ! 💪',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onGradient,
            ),
          ),
        ),
      );
      context.go('/progress');
    } else {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 6),
          content: Text(
            error,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onGradient,
            ),
          ),
        ),
      );
    }
  }

  void _abandon() {
    ref.read(activeSessionProvider.notifier).cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);

    // Séance vidée (dernier exercice retiré) → on ferme la feuille.
    if (!session.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Séance en cours', style: AppTextStyles.headingMedium),
              const SizedBox(height: 4),
              Text(
                '${session.exerciseCount} exercice${session.exerciseCount > 1 ? 's' : ''} · ${session.totalSets} séries · ${session.totalVolume.toStringAsFixed(0)} kg',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: session.exercises.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final ex = session.exercises[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ex.exercise.name,
                                  style: AppTextStyles.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${ex.completedSets} série${ex.completedSets > 1 ? 's' : ''} · ${ex.volume.toStringAsFixed(0)} kg',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _submitting
                                ? null
                                : () {
                                    HapticFeedback.selectionClick();
                                    ref
                                        .read(activeSessionProvider.notifier)
                                        .removeExerciseAt(i);
                                  },
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.textHint,
                              size: 22,
                            ),
                            tooltip: 'Retirer',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: _submitting ? 'Enregistrement…' : 'Terminer la séance',
                icon: Icons.check_circle_outline_rounded,
                onPressed: _submitting ? null : _finish,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _submitting ? null : _abandon,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textHint,
                ),
                child: const Text('Abandonner la séance'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
