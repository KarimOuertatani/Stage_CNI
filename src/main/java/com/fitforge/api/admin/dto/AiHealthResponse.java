package com.fitforge.api.admin.dto;

import com.fitforge.api.common.enums.AiFeature;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.Instant;
import java.util.List;

/**
 * Etat de sante des fonctions d'intelligence artificielle.
 *
 * <h2>Trois niveaux de reponse, parce qu'une seule ne suffit pas</h2>
 * <ul>
 *   <li>{@code configured} -- la cle est-elle presente ? Sans elle, tout est
 *       hors service et aucune statistique n'a de sens. C'est la premiere chose
 *       a savoir, et la moins couteuse a obtenir.</li>
 *   <li>{@code features} -- que s'est-il passe recemment ? Un taux d'echec et
 *       une latence par fonction, sur deux fenetres.</li>
 *   <li>{@code recentFailures} -- <b>quoi</b> exactement a echoue. Un taux de
 *       12 % ne dit pas s'il s'agit d'un quota depasse ou d'un service
 *       injoignable ; ces deux pannes n'appellent pas la meme reaction.</li>
 * </ul>
 *
 * <p>La sonde en direct n'est pas incluse ici : elle consomme le quota et se
 * declenche a la demande, sur une route separee.
 */
@Schema(description = "Etat de sante des fonctions IA")
public record AiHealthResponse(

        @Schema(description = "Faux si GEMINI_API_KEY est absente : tout l'IA est alors hors service")
        boolean configured,

        @Schema(description = "Modele utilise par la majorite des fonctions")
        String model,

        @Schema(description = "Modele dedie a la generation de programme (plus capable)")
        String programModel,

        List<FeatureHealth> features,
        List<Failure> recentFailures,
        Instant generatedAt
) {

    /**
     * Sante d'une fonction sur deux fenetres de temps.
     *
     * <p>Les deux fenetres se lisent ensemble : 24 h dit ce qui se passe
     * maintenant, 7 jours donne la reference a laquelle le comparer. Un taux
     * d'echec de 8 % n'a aucun sens seul -- il faut savoir si la semaine
     * tournait a 1 % ou a 9 %.
     *
     * <p>{@code avgLatencyMs} ne compte que les appels <b>reussis</b> : un echec
     * reseau rend la main en quelques millisecondes et ferait baisser la moyenne
     * au moment precis ou le service se degrade.
     */
    @Schema(description = "Sante d'une fonction IA")
    public record FeatureHealth(
            AiFeature feature,

            @Schema(description = "Libelle francais affichable", example = "Coach IA")
            String label,

            long calls24h,
            long failures24h,
            @Schema(description = "Taux d'echec sur 24 h, en pourcentage")
            double failureRate24h,
            @Schema(description = "Latence moyenne des appels REUSSIS sur 24 h, en ms")
            Long avgLatencyMs24h,
            Long maxLatencyMs24h,

            long calls7d,
            long failures7d,
            double failureRate7d
    ) {}

    /** Un echec recent, reduit a ce qui aide a diagnostiquer. */
    @Schema(description = "Echec recent")
    public record Failure(
            AiFeature feature,
            @Schema(description = "Code HTTP ou classe d'exception", example = "HTTP_503")
            String errorType,
            long latencyMs,
            Instant occurredAt
    ) {}
}
