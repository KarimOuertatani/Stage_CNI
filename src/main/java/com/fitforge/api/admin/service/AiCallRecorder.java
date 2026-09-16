package com.fitforge.api.admin.service;

import com.fitforge.api.common.enums.AiFeature;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientResponseException;

import java.util.function.Supplier;

/**
 * Mesure les appels aux modeles de langage et en confie la trace a
 * {@link AiCallLogWriter}.
 *
 * <h2>Usage</h2>
 * Chaque client Gemini enveloppe son appel sortant :
 * <pre>{@code
 * return recorder.measure(AiFeature.COACH_CHAT, () -> execute(...));
 * }</pre>
 *
 * <h2>La mesure ne doit jamais changer le comportement mesure</h2>
 * C'est la contrainte qui dicte toute la classe.
 *
 * <p>L'exception d'origine est <b>relancee telle quelle</b>, sans etre
 * enveloppee. Les services en amont distinguent des types precis -- en
 * particulier {@code ModelUnavailableException}, qui evite de debiter le quota
 * journalier d'un adherent quand Gemini n'a rien traite. La remplacer par une
 * exception generique casserait cette regle sans que rien ne le signale.
 *
 * <p>L'ecriture est deleguee a un bean distinct pour que sa transaction
 * independante soit effective : voir l'en-tete de {@link AiCallLogWriter}.
 */
@Service
@RequiredArgsConstructor
public class AiCallRecorder {

    private final AiCallLogWriter writer;

    /**
     * Execute l'appel, mesure sa duree, enregistre le resultat, puis renvoie ou
     * relance exactement ce que l'appel a produit.
     */
    public <T> T measure(AiFeature feature, Supplier<T> call) {
        long start = System.nanoTime();
        try {
            T result = call.get();
            writer.write(feature, true, elapsedMs(start), null);
            return result;

        } catch (RuntimeException e) {
            writer.write(feature, false, elapsedMs(start), errorTypeOf(e));
            throw e;   // intact : voir l'en-tete de classe
        }
    }

    /**
     * Nature de l'echec, sous une forme exploitable et <b>sans secret</b>.
     *
     * <p>Pour une reponse HTTP, on ne garde que le code. Le corps d'erreur de
     * Google reprend parfois la cle d'API fournie : les clients du projet
     * appliquent deja cette regle dans leurs journaux, et il serait vain de la
     * respecter dans les logs pour l'enfreindre en base.
     */
    private String errorTypeOf(RuntimeException e) {
        if (e instanceof RestClientResponseException http) {
            return "HTTP_" + http.getStatusCode().value();
        }
        return e.getClass().getSimpleName();
    }

    private static long elapsedMs(long startNanos) {
        return (System.nanoTime() - startNanos) / 1_000_000L;
    }
}
