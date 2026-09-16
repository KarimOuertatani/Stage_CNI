package com.fitforge.api.sleep.service;

import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.sleep.dto.SaveSleepRequest;
import com.fitforge.api.sleep.dto.SleepDayResponse;
import com.fitforge.api.sleep.dto.SleepEntryResponse;
import com.fitforge.api.sleep.dto.SleepStatusResponse;
import com.fitforge.api.sleep.dto.SleepWeekResponse;
import com.fitforge.api.sleep.entity.SleepEntry;
import com.fitforge.api.sleep.repository.SleepEntryRepository;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.entity.UserProfile;
import com.fitforge.api.user.repository.UserProfileRepository;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Le journal de sommeil : saisie d'une nuit, etat du jour, semaine.
 *
 * <h2>Une nuit par jour, corrigeable</h2>
 *
 * <p>La saisie est un <b>upsert</b> : renvoyer sa nuit corrige la ligne
 * existante au lieu d'en empiler une seconde. C'est ce qui rend le geste sans
 * risque — se tromper d'une heure et rouvrir le formulaire est le cas normal,
 * pas une exception a gerer. La contrainte d'unicite en base (V17) tient la
 * promesse meme si deux appels partent en meme temps.
 *
 * <h2>Ce que la saisie met a jour ailleurs</h2>
 *
 * <p>Chaque nuit enregistree recalcule {@code averageSleepHours} du profil.
 * Cette colonne existait avant ce module : elle etait <b>declaree</b> a
 * l'inscription (« je dors environ 7 h ») et n'a jamais bouge depuis. Elle est
 * pourtant lue par le coach IA et par le generateur de programme.
 *
 * <p>La brancher sur les nuits reellement saisies rend ces deux
 * fonctionnalites plus justes <b>sans toucher a une ligne de leur code</b> :
 * un adherent qui dort mal recoit desormais des conseils qui en tiennent
 * compte, parce que la donnee qu'ils lisaient deja est devenue vraie.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class SleepService {

    /**
     * Fenetre de recalcul de la moyenne du profil, en jours.
     *
     * <p>Trente jours : assez long pour absorber une mauvaise semaine, assez
     * court pour qu'un changement d'habitude se voie. Une moyenne sur tout
     * l'historique deviendrait insensible au bout de quelques mois — c'est
     * exactement ce qu'on reproche a la valeur declaree qu'elle remplace.
     */
    private static final int PROFILE_AVERAGE_WINDOW_DAYS = 30;

    /** Nombre de jours d'une semaine affichee. */
    private static final int WEEK_LENGTH = 7;

    private final SleepEntryRepository sleepRepo;
    private final UserRepository userRepo;
    private final UserProfileRepository profileRepo;
    private final SleepAdvisor advisor;

    // ═════════════════════════════════════════════════════════════════
    //  Etat du jour
    // ═════════════════════════════════════════════════════════════════

    /**
     * Faut-il demander sa nuit a l'adherent, et qu'affiche l'accueil ?
     *
     * <p>Les deux reponses en un appel — elles sont demandees au meme moment,
     * au lancement de l'application.
     */
    @Transactional(readOnly = true)
    public SleepStatusResponse status(UUID userId) {
        LocalDate today = LocalDate.now();
        boolean loggedToday = sleepRepo.findByUserIdAndSleepDate(userId, today).isPresent();

        SleepEntryResponse latest = sleepRepo.findTopByUserIdOrderBySleepDateDesc(userId)
                .map(this::toResponse)
                .orElse(null);

        return new SleepStatusResponse(loggedToday, latest);
    }

    // ═════════════════════════════════════════════════════════════════
    //  Saisie
    // ═════════════════════════════════════════════════════════════════

    /**
     * Enregistre (ou corrige) une nuit, et renvoie le conseil qui va avec.
     *
     * @throws BusinessException date dans le futur, ou duree invraisemblable
     */
    @Transactional
    public SleepEntryResponse save(UUID userId, SaveSleepRequest req) {
        LocalDate date = req.sleepDate() != null ? req.sleepDate() : LocalDate.now();

        // Une nuit future n'existe pas encore. Le cas vient soit d'une horloge
        // d'appareil dereglee, soit d'un appel construit a la main — dans les
        // deux cas, l'accepter polluerait l'histogramme d'une barre qu'aucun
        // ecran ne sait afficher.
        if (date.isAfter(LocalDate.now())) {
            throw new BusinessException("On ne peut pas enregistrer une nuit a venir.");
        }

        int duration = SleepEntry.computeDuration(req.bedTime(), req.wakeTime());
        if (duration < SleepEntry.MIN_DURATION_MINUTES
                || duration > SleepEntry.MAX_DURATION_MINUTES) {
            // Le message donne la duree calculee : c'est presque toujours une
            // inversion coucher/lever, et la voir suffit a comprendre.
            throw new BusinessException(
                    "Cette nuit ferait " + formatDuration(duration)
                            + ". Verifie l'heure de coucher et celle de lever.");
        }

        SleepEntry entry = sleepRepo.findByUserIdAndSleepDate(userId, date)
                .orElseGet(() -> newEntry(userId, date));

        entry.setBedTime(req.bedTime());
        entry.setWakeTime(req.wakeTime());
        entry.refreshDuration();

        SleepEntry saved = sleepRepo.save(entry);
        refreshProfileAverage(userId);

        log.debug("Nuit enregistree : {} min le {}", saved.getDurationMinutes(), date);
        return toResponse(saved);
    }

    private SleepEntry newEntry(UUID userId, LocalDate date) {
        User user = userRepo.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));
        return SleepEntry.builder().user(user).sleepDate(date).build();
    }

    /**
     * Reporte la moyenne des trente derniers jours dans le profil.
     *
     * <p>Un echec ici ne doit <b>jamais</b> faire echouer la saisie : la nuit
     * est deja enregistree, et c'est elle qui compte. La moyenne du profil est
     * un confort pour d'autres modules, pas la donnee de reference.
     */
    private void refreshProfileAverage(UUID userId) {
        Double averageMinutes = sleepRepo.averageDurationSince(
                userId, LocalDate.now().minusDays(PROFILE_AVERAGE_WINDOW_DAYS));
        if (averageMinutes == null) {
            return;
        }
        UserProfile profile = profileRepo.findByUserId(userId).orElse(null);
        if (profile == null) {
            return;
        }
        // Arrondi au dixieme d'heure : le profil affiche « 7,4 h », pas
        // « 7,3833333 h ».
        double hours = Math.round(averageMinutes / 6.0) / 10.0;
        profile.setAverageSleepHours(hours);
        profileRepo.save(profile);
    }

    // ═════════════════════════════════════════════════════════════════
    //  La semaine
    // ═════════════════════════════════════════════════════════════════

    /**
     * Les sept jours d'une semaine, avec moyenne, score et conseils.
     *
     * @param anyDayOfWeek n'importe quelle date de la semaine voulue ;
     *                     {@code null} = la semaine en cours
     */
    @Transactional(readOnly = true)
    public SleepWeekResponse week(UUID userId, LocalDate anyDayOfWeek) {
        LocalDate reference = anyDayOfWeek != null ? anyDayOfWeek : LocalDate.now();
        LocalDate weekStart = reference.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
        LocalDate weekEnd = weekStart.plusDays(WEEK_LENGTH - 1L);

        List<SleepEntry> entries = sleepRepo
                .findByUserIdAndSleepDateBetweenOrderBySleepDateAsc(userId, weekStart, weekEnd);

        // Indexation par date : l'histogramme a besoin des SEPT jours, y compris
        // les creux. Parcourir la liste pour chaque jour serait quadratique
        // pour rien.
        Map<LocalDate, SleepEntry> byDate = new HashMap<>();
        for (SleepEntry entry : entries) {
            byDate.put(entry.getSleepDate(), entry);
        }

        List<SleepDayResponse> days = new ArrayList<>(WEEK_LENGTH);
        for (int i = 0; i < WEEK_LENGTH; i++) {
            LocalDate date = weekStart.plusDays(i);
            SleepEntry entry = byDate.get(date);
            days.add(entry == null ? SleepDayResponse.empty(date) : toDayResponse(entry));
        }

        Integer score = advisor.score(entries);
        Integer average = entries.isEmpty() ? null : advisor.averageMinutes(entries);

        // Le nombre de nuits attendues s'arrete AUJOURD'HUI pour la semaine en
        // cours : reprocher a quelqu'un, un mercredi, les quatre nuits qu'il
        // n'a pas encore vecues n'aurait aucun sens.
        LocalDate currentWeekStart = LocalDate.now()
                .with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
        boolean isCurrentWeek = weekStart.isEqual(currentWeekStart);
        int expectedNights = isCurrentWeek
                ? (int) (LocalDate.now().toEpochDay() - weekStart.toEpochDay()) + 1
                : WEEK_LENGTH;

        return new SleepWeekResponse(
                weekStart,
                weekEnd,
                days,
                entries.size(),
                average,
                score,
                advisor.weeklyHeadline(score),
                advisor.weekendCatchUpMinutes(entries),
                advisor.weeklyTips(entries, expectedNights),
                isCurrentWeek);
    }

    // ═════════════════════════════════════════════════════════════════
    //  Suppression
    // ═════════════════════════════════════════════════════════════════

    /** Supprime une nuit (correction d'une saisie erronee). */
    @Transactional
    public void delete(UUID userId, UUID entryId) {
        SleepEntry entry = sleepRepo.findById(entryId)
                .orElseThrow(() -> new ResourceNotFoundException("Nuit introuvable"));
        // 404 et non 403 : on ne revele pas l'existence de la ressource d'un
        // tiers, comme partout ailleurs dans le projet.
        if (!entry.getUser().getId().equals(userId)) {
            throw new ResourceNotFoundException("Nuit introuvable");
        }
        sleepRepo.delete(entry);
        refreshProfileAverage(userId);
    }

    // ═════════════════════════════════════════════════════════════════
    //  Mapping
    // ═════════════════════════════════════════════════════════════════

    // Mapping ecrit a la main plutot que via MapStruct : les trois champs qui
    // comptent (tranche, titre, conseil) ne sont pas des copies mais des
    // CALCULS de SleepAdvisor. Un mapper genere aurait de toute facon fallu les
    // lui deleguer un par un.

    private SleepEntryResponse toResponse(SleepEntry entry) {
        int minutes = entry.getDurationMinutes();
        return new SleepEntryResponse(
                entry.getId(),
                entry.getSleepDate(),
                entry.getBedTime(),
                entry.getWakeTime(),
                minutes,
                advisor.bandOf(minutes),
                advisor.headlineFor(minutes),
                advisor.adviceFor(minutes));
    }

    private SleepDayResponse toDayResponse(SleepEntry entry) {
        int minutes = entry.getDurationMinutes();
        return new SleepDayResponse(
                entry.getId(),
                entry.getSleepDate(),
                entry.getSleepDate().getDayOfWeek().getValue(),
                minutes,
                advisor.bandOf(minutes),
                entry.getBedTime(),
                entry.getWakeTime());
    }

    /** « 7 h 30 » — utilise dans le message d'erreur de saisie. */
    private String formatDuration(int minutes) {
        return (minutes / 60) + " h " + String.format("%02d", minutes % 60);
    }
}
