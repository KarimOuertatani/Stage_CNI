package com.fitforge.api.admin.service;

import com.fitforge.api.admin.dto.AdminDashboardResponse;
import com.fitforge.api.admin.repository.AdminNotificationRepository;
import com.fitforge.api.admin.repository.AdminStatsRepository;
import com.fitforge.api.admin.repository.AiCallLogRepository;
import com.fitforge.api.admin.repository.ProblemReportRepository;
import com.fitforge.api.coaching.repository.CoachProfileRepository;
import com.fitforge.api.common.enums.CoachStatus;
import com.fitforge.api.common.enums.ProblemStatus;
import com.fitforge.api.common.enums.Role;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Agregation du tableau de bord.
 *
 * <h2>Une methode, une page</h2>
 * Tout est renvoye en un seul appel. Decouper en huit routes ferait payer a la
 * page d'accueil huit allers-retours, huit poignees de main TLS et huit
 * verifications de jeton pour afficher une grille de tuiles qui apparaissent
 * ensemble de toute facon.
 *
 * <p>Le cout cote base reste faible : ce sont des {@code count} sur des colonnes
 * indexees, plus une seule agregation groupee pour la courbe.
 */
@Service
@RequiredArgsConstructor
public class AdminDashboardService {

    /** Fenetre de la courbe et des compteurs d'activite. */
    private static final int WINDOW_DAYS = 30;

    private final AdminStatsRepository stats;
    private final CoachProfileRepository coachProfileRepo;
    private final ProblemReportRepository problemRepo;
    private final AdminNotificationRepository notificationRepo;
    private final AiCallLogRepository aiCallRepo;

    @Transactional(readOnly = true)
    public AdminDashboardResponse dashboard() {
        Instant now = Instant.now();
        Instant since30d = now.minus(Duration.ofDays(WINDOW_DAYS));
        Instant since7d = now.minus(Duration.ofDays(7));
        Instant since24h = now.minus(Duration.ofHours(24));
        LocalDate day30 = LocalDate.now().minusDays(WINDOW_DAYS);

        long totalCoaches = stats.countByRole(Role.COACH);

        return new AdminDashboardResponse(
                // ── A traiter ────────────────────────────────────
                coachProfileRepo.countByStatus(CoachStatus.PENDING),
                problemRepo.countByStatus(ProblemStatus.NEW),
                problemRepo.countByStatus(ProblemStatus.IN_PROGRESS),
                notificationRepo.countByReadAtIsNull(),

                // ── Comptes ──────────────────────────────────────
                stats.countByRole(Role.ADHERENT),
                totalCoaches,
                coachProfileRepo.countByStatus(CoachStatus.APPROVED),
                stats.countByRoleAndEnabled(Role.ADHERENT, false)
                        + stats.countByRoleAndEnabled(Role.COACH, false),
                stats.countUsersCreatedSince(since30d),
                stats.countActiveSince(since7d),

                // ── Activite ─────────────────────────────────────
                stats.countWorkoutLogsSince(day30),
                stats.countNutritionEntriesSince(day30),
                stats.countSleepEntriesSince(day30),
                aiCallRepo.countSince(since24h),
                aiCallRepo.countFailuresSince(since24h),

                // ── Courbe ───────────────────────────────────────
                registrationsPerDay(since30d));
    }

    /**
     * Inscriptions jour par jour, <b>jours creux compris</b>.
     *
     * <p>La requete SQL ne renvoie que les jours ou quelqu'un s'est inscrit. On
     * reconstruit ici la serie complete : sans cela, une courbe de 30 jours dont
     * la moitie sont vides afficherait 15 points equidistants, et une periode
     * creuse serait graphiquement indiscernable d'une periode normale.
     */
    private List<AdminDashboardResponse.DailyCount> registrationsPerDay(Instant since) {
        Map<LocalDate, Long> counts = new HashMap<>();
        for (Object[] row : stats.countRegistrationsPerDaySince(since)) {
            counts.put(toLocalDate(row[0]), ((Number) row[1]).longValue());
        }

        List<AdminDashboardResponse.DailyCount> series = new ArrayList<>(WINDOW_DAYS + 1);
        LocalDate start = LocalDate.now().minusDays(WINDOW_DAYS);
        for (int i = 0; i <= WINDOW_DAYS; i++) {
            LocalDate day = start.plusDays(i);
            series.add(new AdminDashboardResponse.DailyCount(day, counts.getOrDefault(day, 0L)));
        }
        return series;
    }

    /**
     * Normalise ce que renvoie la base pour la date groupee.
     *
     * <p>Le type exact depend du pilote et de la facon dont {@code cast(... as
     * localdate)} est traduit : selon les versions, on recoit un
     * {@link LocalDate} ou un {@code java.sql.Date}. Un transtypage direct
     * fonctionnerait donc en developpement et echouerait ailleurs -- ce genre de
     * panne ne se voit qu'en production.
     */
    private static LocalDate toLocalDate(Object value) {
        if (value instanceof LocalDate localDate) {
            return localDate;
        }
        if (value instanceof java.sql.Date sqlDate) {
            return sqlDate.toLocalDate();
        }
        if (value instanceof java.util.Date date) {
            return date.toInstant().atZone(ZoneId.systemDefault()).toLocalDate();
        }
        return LocalDate.parse(value.toString());
    }
}
