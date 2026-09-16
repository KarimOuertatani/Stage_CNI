import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_depth.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/neon_badge.dart';
import '../../../../core/widgets/tilt_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../nutrition/presentation/providers/nutrition_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../sleep/data/sleep_models.dart';
import '../../../sleep/presentation/providers/sleep_provider.dart';
import '../../../sleep/presentation/widgets/sleep_prompt_gate.dart';
import '../../../../core/widgets/screen_background.dart';
import '../../../../shared/navigation/main_shell.dart';
import '../widgets/home_greeting_header.dart';
import '../widgets/quick_stats_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Bottom sheet profil : préférence de thème + déconnexion.
  void _showProfileSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    final user = ref.read(authProvider).user;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Consumer(
        builder: (context, sheetRef, _) {
          final mode = sheetRef.watch(themeModeProvider);
          return SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Identité
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.heroGradient,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (user?.fullName.isNotEmpty ?? false)
                              ? user!.fullName[0].toUpperCase()
                              : 'U',
                          style: AppTextStyles.headingMedium.copyWith(
                            color: AppColors.onGradient,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'Utilisateur',
                              style: AppTextStyles.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? '',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(color: AppColors.divider),
                  const SizedBox(height: 8),

                  // Accès au profil complet (données physiques, IMC, score)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.primaryText,
                    ),
                    title: Text('Mon profil', style: AppTextStyles.titleMedium),
                    subtitle: Text(
                      'Poids, taille, objectif, IMC, score',
                      style: AppTextStyles.caption,
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textHint,
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.push('/profile');
                    },
                  ),

                  // Préférence de thème
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      mode == AppThemeMode.dark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: AppColors.primaryText,
                    ),
                    title: Text(
                      'Mode sombre',
                      style: AppTextStyles.titleMedium,
                    ),
                    subtitle: Text(
                      mode == AppThemeMode.dark ? 'Activé' : 'Désactivé',
                      style: AppTextStyles.caption,
                    ),
                    trailing: Switch(
                      value: mode == AppThemeMode.dark,
                      activeThumbColor: AppColors.primary,
                      onChanged: (_) {
                        HapticFeedback.selectionClick();
                        sheetRef.read(themeModeProvider.notifier).toggle();
                      },
                    ),
                  ),

                  // Déconnexion
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.logout_rounded,
                      color: AppColors.errorText,
                    ),
                    title: Text(
                      'Déconnexion',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.errorText,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      ref.read(authProvider.notifier).logout();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userName = authState.user?.fullName ?? 'Utilisateur';

    // ── Stats réelles (backend) ───────────────────────────────────
    final nutrition = ref.watch(nutritionProvider);
    final profileState = ref.watch(profileProvider);
    final sessions = profileState.score?.sessionsCompleted ?? 0;
    final weeklyTarget = profileState.profile?.weeklyWorkoutTarget ?? 5;
    final consumedCalories = nutrition.todayCalories;
    final calorieGoal = nutrition.dailyGoal;
    final sleepHours = profileState.profile?.averageSleepHours;
    // La dernière nuit connue — pas forcément celle d'aujourd'hui. Quelqu'un
    // qui a sauté la saisie hier doit quand même voir sa dernière nuit : une
    // tuile qui repasse à « — » donne l'impression d'avoir perdu l'historique.
    final lastNight = ref.watch(sleepStatusProvider).value?.latest;

    return Scaffold(
      // L'accueil était le seul des 19 écrans à recomposer son fond à la main
      // (dégradé + halos) au lieu de passer par ScreenBackground. La copie
      // avait dérivé : intensité 1,0 contre 0,7 partout ailleurs, ce qui ne se
      // voyait qu'ici — le halo bas débordait sous la barre de navigation.
      body: ScreenBackground(
        // `bottom: false` — comme les quatre autres onglets. Le shell est en
        // `extendBody: true`, donc le Scaffold annonce au corps une marge
        // basse égale à la hauteur de la barre de navigation. Avec un
        // SafeArea complet, le contenu s'arrêtait NET au ras de la barre :
        // derrière le verre il ne restait que le fond uni, lu comme une
        // bande. Le contenu doit passer dessous pour qu'on le voie au
        // travers ; c'est le SizedBox de fin qui dégage la dernière carte.
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ne dessine rien : ouvre le pop-up « comment as-tu dormi ? »
                // à la première ouverture de la journée, une fois l'état du
                // sommeil chargé. Toute la logique est dans la feature
                // sommeil, l'accueil n'en porte que la ligne.
                const SleepPromptGate(),

                // Header
                HomeGreetingHeader(
                  userName: userName,
                  avatarUrl: authState.user?.avatarUrl,
                  onProfileTap: () => _showProfileSheet(context, ref),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1),
                const SizedBox(height: 24),

                // ── La bannière ─────────────────────────────────────────
                // Elle affichait « Aujourd'hui à 18:30 • Cardio & Jambes » :
                // une donnée INVENTÉE, codée en dur. Un écran d'accueil qui
                // annonce un rendez-vous imaginaire détruit la confiance dans
                // tous les autres chiffres de la page.
                // Elle porte désormais l'avancement RÉEL de la semaine.
                _HeroBanner(
                      sessions: sessions,
                      weeklyTarget: weeklyTarget,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.go('/workout');
                      },
                    )
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 550.ms)
                    .scale(begin: const Offset(0.95, 0.95)),
                const SizedBox(height: 28),

                // Summary title with small neon decoration line
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: AppColors.accentGlow,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Activités du jour',
                      style: AppTextStyles.headingMedium,
                    ),
                  ],
                ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
                const SizedBox(height: 16),

                // Stats Grid
                // Grille adaptative : 2 colonnes sur téléphone, davantage sur
                // tablette/desktop. On fixe la HAUTEUR (mainAxisExtent) au lieu
                // d'un childAspectRatio : un ratio figé imposait ~112 px alors
                // que le contenu en réclame ~120, d'où le débordement — et le
                // problème empirait dès que la police système grandissait.
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  // `padding` explicite, même à zéro : sans lui, un GridView
                  // reprend AUTOMATIQUEMENT la marge verticale du MediaQuery.
                  // Comme le shell est en `extendBody: true`, celle-ci vaut la
                  // hauteur de la barre de navigation — soit ~120 px de vide
                  // injectés entre la grille et la section suivante.
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: Responsive.gridColumns(context),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: Responsive.scaledExtent(context, 126),
                  ),
                  children: [
                    // Chaque tuile MÈNE quelque part : une statistique sans
                    // action est une impasse. Voir « 1 240 kcal » donne envie
                    // d'ouvrir le journal, pas de fixer le chiffre.
                    QuickStatsCard(
                      title: 'Séances',
                      value: '$sessions / $weeklyTarget',
                      unit: 'semaine',
                      icon: Icons.fitness_center,
                      iconColor: AppColors.primary,
                      onTap: () => context.go('/workout'),
                    ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.05),
                    QuickStatsCard(
                      title: 'Calories',
                      value: '$consumedCalories',
                      unit: 'kcal / $calorieGoal',
                      icon: Icons.local_fire_department,
                      iconColor: AppColors.accent,
                      onTap: () => context.go('/nutrition'),
                    ).animate().fadeIn(delay: 350.ms).slideX(begin: 0.05),
                    QuickStatsCard(
                      title: 'Objectif',
                      value: profileState.profile?.targetWeightKg != null
                          ? '${profileState.profile!.targetWeightKg}'
                          : '—',
                      unit: 'kg visés',
                      icon: Icons.flag_outlined,
                      iconColor: Colors.blue,
                      onTap: () => context.push('/profile'),
                    ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.05),
                    // La tuile affiche la DERNIÈRE NUIT réelle, plus la
                    // moyenne déclarée à l'inscription : « 7,3 h en général »
                    // ne dit rien de la nuit qu'on vient de passer, et c'est
                    // celle-là qu'on regarde le matin. La moyenne déclarée sert
                    // de repli tant qu'aucune nuit n'a été saisie.
                    QuickStatsCard(
                      title: 'Sommeil',
                      value: lastNight != null
                          ? formatDuration(lastNight.durationMinutes)
                          : (sleepHours != null ? '$sleepHours h' : '—'),
                      unit: lastNight != null
                          ? (lastNight.headline ?? 'cette nuit')
                          : 'à renseigner',
                      icon: Icons.bedtime,
                      iconColor: lastNight?.band?.color ?? Colors.amber,
                      onTap: () => context.push('/sleep'),
                    ).animate().fadeIn(delay: 450.ms).slideX(begin: 0.05),
                  ],
                ),
                // 24 comme les autres séparateurs de bloc de l'écran. À 32,
                // c'était l'écart le plus large de la page — deux fois le
                // rythme de 16 utilisé partout ailleurs — et il se lisait
                // comme un trou entre la grille et la section suivante.
                const SizedBox(height: 24),

                // Quick Navigation Cards
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: AppColors.primaryGlow,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Sections de l\'application',
                      style: AppTextStyles.headingMedium,
                    ),
                  ],
                ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                const SizedBox(height: 16),

                _QuickNavRowCard(
                  title: 'Séances & Exercices',
                  subtitle:
                      'Lancez une séance et loggez vos séries en quelques taps.',
                  icon: Icons.fitness_center_rounded,
                  gradient: AppColors.primaryGradient,
                  onTap: () => context.go('/workout'),
                ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.05),
                const SizedBox(height: 16),

                _QuickNavRowCard(
                  title: 'Progression corporelle 3D',
                  subtitle:
                      'Votre corps s\'illumine selon les zones travaillées cette semaine.',
                  icon: Icons.view_in_ar_rounded,
                  gradient: AppColors.accentGradient,
                  onTap: () => context.go('/progress'),
                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.05),
                const SizedBox(height: 16),

                _QuickNavRowCard(
                  title: 'Conseils & Coaching',
                  subtitle:
                      'Discutez avec nos coachs professionnels ou notre IA intégrée.',
                  icon: Icons.chat_bubble_rounded,
                  gradient: AppColors.warmGradient,
                  onTap: () => context.go('/coaching'),
                ).animate().fadeIn(delay: 650.ms).slideY(begin: 0.05),
                const SizedBox(height: 16),

                _QuickNavRowCard(
                  title: 'Nutrition & Macros',
                  subtitle:
                      'Suivez vos repas quotidiennement et maîtrisez vos objectifs.',
                  icon: Icons.restaurant,
                  gradient: AppColors.successGradient,
                  onTap: () => context.go('/nutrition'),
                ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.05),
                // Dégage la barre de navigation flottante : sans cette marge,
                // la dernière carte reste coincée dessous.
                SizedBox(height: MainShell.heightOf(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  La bannière d'accueil
// ═════════════════════════════════════════════════════════════════════

/// Bannière principale : l'avancement **réel** de la semaine.
///
/// ## Ce qu'elle affichait avant
///
/// « Coaching IA avec FitForge — Aujourd'hui à 18:30 • Cardio & Jambes », codé
/// en dur. Aucun rendez-vous n'existait. Un écran d'accueil qui annonce une
/// séance imaginaire ne fait pas qu'induire en erreur sur ce point-là : il rend
/// **tous** les autres chiffres de la page suspects.
///
/// Elle porte désormais des données qui existent : séances faites sur séances
/// visées, et un message qui change selon l'avancement.
///
/// ## Le relief
///
/// C'est le seul élément de l'écran à cumuler les trois effets — halo coloré
/// marqué, balayage lumineux périodique, inclinaison plus prononcée (8° contre
/// 6°). Cette accumulation est ce qui en fait le point d'entrée évident. Elle
/// n'est **pas** répétée ailleurs : appliquée partout, elle n'attirerait plus
/// l'œil nulle part.
class _HeroBanner extends StatelessWidget {
  final int sessions;
  final int weeklyTarget;
  final VoidCallback onTap;

  const _HeroBanner({
    required this.sessions,
    required this.weeklyTarget,
    required this.onTap,
  });

  /// Message adapté à l'avancement. Un texte fixe ne récompense jamais l'effort.
  ({String title, String subtitle}) get _message {
    if (weeklyTarget <= 0) {
      return (
        title: 'Prêt à t\'entraîner ?',
        subtitle: 'Lance ta séance du jour',
      );
    }
    if (sessions == 0) {
      return (
        title: 'On commence la semaine ?',
        subtitle: '$weeklyTarget séances prévues · aucune encore faite',
      );
    }
    if (sessions >= weeklyTarget) {
      return (
        title: 'Objectif de la semaine atteint',
        subtitle: '$sessions séances sur $weeklyTarget · continue comme ça',
      );
    }
    final left = weeklyTarget - sessions;
    return (
      title: left == 1 ? 'Plus qu\'une séance' : 'Plus que $left séances',
      subtitle: '$sessions sur $weeklyTarget cette semaine',
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    final progress = weeklyTarget > 0
        ? (sessions / weeklyTarget).clamp(0.0, 1.0)
        : 0.0;
    final done = sessions >= weeklyTarget && weeklyTarget > 0;

    return TiltCard(
      onTap: onTap,
      borderRadius: 24,
      // Plus incliné que les autres cartes : c'est l'élément principal, il a le
      // droit de réagir plus franchement.
      maxTilt: 8,
      restingShadow: AppDepth.glow(AppColors.primary, strength: 0.75),
      liftedShadow: AppDepth.glow(AppColors.primary, strength: 1.25),
      sheenStrength: 0.20,
      child: SweepShine(
        borderRadius: 24,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              // Halo interne : une lumière qui vient du coin haut-droit, sous
              // le contenu. Sans lui, le dégradé est parfaitement lisse — donc
              // parfaitement plat.
              Positioned(
                right: -30,
                top: -40,
                child: IgnorePointer(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.onGradient.withValues(alpha: 0.18),
                          AppColors.onGradient.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const PulseDot(
                                  color: AppColors.onGradient,
                                  size: 6,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  done ? 'SEMAINE COMPLÈTE' : 'CETTE SEMAINE',
                                  style: AppTextStyles.overline.copyWith(
                                    color: AppColors.onGradient.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              message.title,
                              style: AppTextStyles.headingSmall.copyWith(
                                color: AppColors.onGradient,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message.subtitle,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.onGradient.withValues(
                                  alpha: 0.85,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.onGradient.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          // Un anneau clair : le bouton se détache du dégradé
                          // au lieu d'y fondre.
                          border: Border.all(
                            color: AppColors.onGradient.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Icon(
                          done
                              ? Icons.emoji_events_rounded
                              : Icons.play_arrow_rounded,
                          color: AppColors.onGradient,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  if (weeklyTarget > 0) ...[
                    const SizedBox(height: 16),
                    // La barre transforme un chiffre en image : « 3 sur 5 »
                    // demande un calcul, une barre remplie aux deux tiers non.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: AppColors.onGradient.withValues(
                          alpha: 0.22,
                        ),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.onGradient,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Les cartes de navigation
// ═════════════════════════════════════════════════════════════════════

/// Rangée de navigation vers une section.
///
/// L'ancienne version se contentait de rétrécir à 0,98 au tap — un retour
/// correct mais plat. Elle s'incline désormais vers le doigt, et son ombre est
/// **teintée de son propre dégradé** : les quatre rangées éclairent chacune un
/// morceau de fond différent, ce qui les distingue autrement que par leur icône.
///
/// La pastille d'icône reçoit un léger relief interne (bordure claire en haut) :
/// c'est ce qui la fait lire comme un bouton en volume plutôt que comme un
/// carré coloré.
class _QuickNavRowCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _QuickNavRowCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = gradient.colors.first;

    return TiltCard(
      onTap: onTap,
      borderRadius: 20,
      restingShadow: AppDepth.tinted(tint, strength: 0.5),
      liftedShadow: AppDepth.tinted(tint, strength: 1.1),
      sheenColor: Color.lerp(Colors.white, tint, 0.3)!,
      // `boxShadow: []` — l'élévation vient du TiltCard, pas de la carte.
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        borderRadius: 20,
        backgroundColor: AppColors.glassSurface,
        boxShadow: const [],
        tintColor: tint,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(16),
                // Bordure claire : simule l'arête supérieure d'un objet en
                // volume, celle qui reçoit la lumière.
                border: Border.all(
                  color: AppColors.onGradient.withValues(alpha: 0.22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: tint.withValues(alpha: 0.42),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: -3,
                  ),
                ],
              ),
              child: Icon(icon, color: AppColors.onGradient, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textHint,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
