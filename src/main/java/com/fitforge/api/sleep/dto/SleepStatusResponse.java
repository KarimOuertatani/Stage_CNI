package com.fitforge.api.sleep.dto;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * L'etat du jour, en un seul appel.
 *
 * <h2>Pourquoi les deux informations voyagent ensemble</h2>
 *
 * <p>L'application a besoin de repondre a deux questions au demarrage, et elle
 * en a besoin <b>en meme temps</b> :
 *
 * <ul>
 *   <li><b>Faut-il ouvrir le pop-up ?</b> → {@link #loggedToday}</li>
 *   <li><b>Qu'affiche la tuile de l'accueil ?</b> → {@link #latest}</li>
 * </ul>
 *
 * <p>Deux routes separees auraient impose deux allers-retours au lancement, sur
 * un ecran qui en fait deja plusieurs.
 *
 * <p><b>{@code latest} n'est pas forcement la nuit d'aujourd'hui.</b> C'est
 * voulu : quelqu'un qui a saute la saisie hier doit quand meme voir sa derniere
 * nuit connue sur l'accueil. Une tuile qui repasse a « — » parce qu'on a saute
 * un jour donne l'impression d'avoir perdu son historique.
 */
@Schema(description = "Etat du sommeil pour aujourd'hui")
public record SleepStatusResponse(

        @Schema(description = "Vrai si la nuit d'aujourd'hui est deja saisie. "
                + "C'est ce qui decide de l'ouverture du pop-up.", example = "false")
        boolean loggedToday,

        @Schema(description = "La derniere nuit connue, quelle que soit sa date. "
                + "Null si l'adherent n'a jamais rien saisi.")
        SleepEntryResponse latest
) {
}
