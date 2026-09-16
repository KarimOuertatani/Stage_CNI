import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/screen_background.dart';
import '../../data/problem_report_models.dart';
import '../providers/problem_report_provider.dart';

/// Écran « Mes signalements ».
///
/// ═══════════════════════════════════════════════════════════════════
///  C'est cet écran qui donne sa valeur au signalement
/// ═══════════════════════════════════════════════════════════════════
/// Un formulaire de contact qui ne renvoie jamais rien apprend vite à ses
/// utilisateurs qu'écrire ne sert à rien. Ce qui fait la différence entre un
/// vrai canal et une boîte à idées, c'est le **retour** : le statut avance, et
/// la réponse de l'équipe s'affiche sous le signalement concerné.
///
/// D'où la mise en page : la réponse n'est pas reléguée dans un détail à
/// ouvrir, elle est visible directement dans la carte.
class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myReportsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mes signalements')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/signaler'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Signaler'),
      ),
      body: ScreenBackground(
        child: SafeArea(
          top: false,
          child: async.when(
            loading: () => const AppListSkeleton(itemCount: 3, itemHeight: 120),
            error: (e, _) => AppErrorState(
              message: 'Impossible de charger tes signalements.',
              onRetry: () => ref.invalidate(myReportsProvider),
            ),
            data: (reports) => reports.isEmpty
                ? const AppEmptyState(
                    icon: Icons.flag_outlined,
                    title: 'Aucun signalement',
                    message:
                        "Si quelque chose ne fonctionne pas ou qu'une donnée "
                        "te semble fausse, dis-le nous : on lit tout.",
                  )
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(myReportsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                      itemCount: reports.length,
                      itemBuilder: (_, i) => _ReportCard(report: reports[i]),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ProblemReport report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final color = problemStatusColor(
      report.status,
      pending: AppColors.warning,
      active: AppColors.primary,
      done: AppColors.success,
      muted: AppColors.textSecondary,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        tintColor: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Entête : statut + date ────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    report.status.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${report.category.emoji} ${report.category.label}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (report.createdAt != null)
                  Text(
                    _relative(report.createdAt!),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              report.subject,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              report.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),

            // ── La réponse de l'équipe ────────────────────────────
            //
            // Visible directement, sans avoir à ouvrir quoi que ce soit :
            // c'est l'information que la personne est venue chercher.
            if (report.adminResponse != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.support_agent_rounded, color: color, size: 15),
                        const SizedBox(width: 7),
                        Text(
                          'RÉPONSE DE L\'ÉQUIPE FITFORGE',
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report.adminResponse!,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (report.status == ProblemStatus.newReport) ...[
              const SizedBox(height: 12),
              Text(
                report.status.hint,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Ancienneté en clair : sur un suivi de demande, « il y a 3 jours » répond
  /// mieux que « 12 févr. » à la question qu'on se pose vraiment.
  static String _relative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    if (diff.inDays < 30) return 'il y a ${diff.inDays} jours';
    return 'il y a ${(diff.inDays / 30).floor()} mois';
  }
}
