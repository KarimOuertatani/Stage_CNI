package com.fitforge.api.admin.service;

import com.fitforge.api.admin.dto.AiHealthResponse;
import com.fitforge.api.admin.entity.AiCallLog;
import com.fitforge.api.admin.repository.AiCallLogRepository;
import com.fitforge.api.common.enums.AiFeature;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;

/**
 * Page de supervision des fonctions IA.
 *
 * <h2>Ce que la page doit permettre de decider</h2>
 * Pas « combien d'appels avons-nous faits », mais <b>« faut-il intervenir, et
 * sur quoi »</b>. Les trois informations qui repondent a cette question sont le
 * taux d'echec compare a sa reference, la latence des appels reussis, et la
 * nature des dernieres erreurs -- un quota depasse et un service injoignable
 * n'appellent pas la meme reaction.
 */
@Service
@RequiredArgsConstructor
public class AdminAiHealthService {

    /** Nombre d'erreurs recentes remontees a la console. */
    private static final int RECENT_FAILURES = 15;

    private final AiCallLogRepository repository;
    private final GeminiProbeClient probeClient;

    @Value("${gemini.api.model:}")
    private String model;

    @Value("${gemini.api.program-model:}")
    private String programModel;

    @Transactional(readOnly = true)
    public AiHealthResponse health() {
        Instant now = Instant.now();
        Map<AiFeature, Row> last24h = aggregate(now.minus(Duration.ofHours(24)));
        Map<AiFeature, Row> last7d = aggregate(now.minus(Duration.ofDays(7)));

        List<AiHealthResponse.FeatureHealth> features = new ArrayList<>();
        for (AiFeature feature : AiFeature.values()) {
            // La sonde n'est pas une fonction de l'application : la mesurer
            // aux cotes du coach IA melangerait un appel de controle
            // declenche par l'administrateur avec l'usage reel des adherents.
            if (feature == AiFeature.HEALTH_PROBE) {
                continue;
            }
            Row day = last24h.getOrDefault(feature, Row.EMPTY);
            Row week = last7d.getOrDefault(feature, Row.EMPTY);

            features.add(new AiHealthResponse.FeatureHealth(
                    feature, labelOf(feature),
                    day.total, day.failures, rate(day),
                    day.avgMs, day.maxMs,
                    week.total, week.failures, rate(week)));
        }

        List<AiHealthResponse.Failure> failures = repository
                .recentFailures(PageRequest.of(0, RECENT_FAILURES))
                .stream()
                .map(this::toFailure)
                .toList();

        return new AiHealthResponse(
                probeClient.isConfigured(), model, programModel, features, failures, now);
    }

    /** Declenche un appel reel au modele et renvoie ce qu'il en est. */
    public GeminiProbeClient.ProbeResult probe() {
        return probeClient.probe();
    }

    // ── Interne ──────────────────────────────────────────────────

    /**
     * Transforme le resultat brut de l'agregation SQL en table indexee par
     * fonction.
     *
     * <p>Les fonctions <b>sans aucun appel</b> sont absentes du resultat SQL --
     * un {@code group by} ne fabrique pas de lignes vides. C'est l'appelant qui
     * complete avec {@link Row#EMPTY}, sinon la page n'afficherait tout
     * simplement pas les fonctions inutilisees, alors que « zero appel en
     * 24 h » est precisement une information a montrer.
     */
    private Map<AiFeature, Row> aggregate(Instant since) {
        Map<AiFeature, Row> byFeature = new EnumMap<>(AiFeature.class);
        for (Object[] r : repository.aggregateSince(since)) {
            byFeature.put((AiFeature) r[0], new Row(
                    toLong(r[1]), toLong(r[2]),
                    r[3] == null ? null : Math.round(((Number) r[3]).doubleValue()),
                    r[4] == null ? null : toLong(r[4])));
        }
        return byFeature;
    }

    private AiHealthResponse.Failure toFailure(AiCallLog log) {
        return new AiHealthResponse.Failure(
                log.getFeature(), log.getErrorType(), log.getLatencyMs(), log.getCreatedAt());
    }

    /** Taux d'echec en pourcentage, arrondi au dixieme. Zero appel -> 0. */
    private static double rate(Row row) {
        if (row.total == 0) return 0d;
        return Math.round((row.failures * 1000d) / row.total) / 10d;
    }

    private static long toLong(Object value) {
        return value == null ? 0L : ((Number) value).longValue();
    }

    /** Libelle francais : la console affiche des mots, pas des constantes. */
    private static String labelOf(AiFeature feature) {
        return switch (feature) {
            case COACH_CHAT -> "Coach IA";
            case MEAL_PHOTO -> "Photo de repas";
            case MEAL_VOICE -> "Ajout vocal";
            case MEAL_TEXT -> "Ajout ecrit";
            case PROGRAM_GENERATION -> "Generation de programme";
            case HEALTH_PROBE -> "Sonde de controle";
        };
    }

    /** Ligne d'agregation intermediaire. */
    private record Row(long total, long failures, Long avgMs, Long maxMs) {
        static final Row EMPTY = new Row(0, 0, null, null);
    }
}
