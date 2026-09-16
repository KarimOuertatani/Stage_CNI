package com.fitforge.api.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDate;
import java.util.List;

/**
 * Le tableau de bord de la console.
 *
 * <h2>Deux natures d'information, et elles ne se melangent pas</h2>
 * <ul>
 *   <li>Ce qui <b>demande une action</b> : dossiers coach en attente,
 *       signalements ouverts. Ces nombres doivent tomber a zero ; tant qu'ils ne
 *       le sont pas, quelqu'un attend une reponse.</li>
 *   <li>Ce qui <b>decrit l'activite</b> : membres, seances, repas, nuits. Ces
 *       nombres ne se « traitent » pas, ils se regardent.</li>
 * </ul>
 * Les afficher dans une meme rangee de tuiles identiques ferait perdre cette
 * distinction, et « 3 dossiers en attente » se lirait comme « 412 membres » :
 * une statistique de plus, sans urgence.
 */
@Schema(description = "Tableau de bord de la console d'administration")
public record AdminDashboardResponse(

        // ── A traiter ────────────────────────────────────────────
        @Schema(description = "Dossiers coach soumis, en attente d'examen")
        long pendingCoachApplications,

        @Schema(description = "Signalements non encore pris en charge")
        long newProblemReports,

        @Schema(description = "Signalements en cours de traitement")
        long inProgressProblemReports,

        @Schema(description = "Notifications non lues")
        long unreadNotifications,

        // ── Comptes ──────────────────────────────────────────────
        long totalMembers,
        long totalCoaches,
        long approvedCoaches,

        @Schema(description = "Comptes suspendus ou dont l'email n'a jamais ete verifie")
        long inactiveAccounts,

        @Schema(description = "Inscriptions des 30 derniers jours")
        long newAccounts30d,

        @Schema(description = "Comptes s'etant connectes dans les 7 derniers jours")
        long activeAccounts7d,

        // ── Activite (30 derniers jours) ─────────────────────────
        long workoutsLogged30d,
        long mealsLogged30d,
        long sleepEntries30d,

        @Schema(description = "Appels aux modeles de langage sur 24 h")
        long aiCalls24h,
        long aiFailures24h,

        // ── Courbe ───────────────────────────────────────────────
        @Schema(description = "Inscriptions jour par jour sur 30 jours, jours creux inclus")
        List<DailyCount> registrationsPerDay
) {
    /**
     * Un point de la courbe.
     *
     * <p>Les jours <b>sans aucune inscription</b> sont presents avec un compte a
     * zero. La base ne les produit pas ({@code group by} ne fabrique pas de
     * lignes vides) : c'est le service qui comble les trous. Sans cela, une
     * courbe de 30 jours dont 12 sont creux afficherait 18 points equidistants
     * -- et une semaine calme ressemblerait a une semaine normale.
     */
    @Schema(description = "Inscriptions d'un jour")
    public record DailyCount(LocalDate date, long count) {}
}
