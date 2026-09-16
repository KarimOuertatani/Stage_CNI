package com.fitforge.api.common.enums;

/**
 * Tranche de duree d'une nuit.
 *
 * <p>C'est le pivot de tout le module sommeil : le conseil affiche, la couleur
 * de la barre dans l'histogramme et une partie du score en decoulent. Envoyer
 * la tranche a l'application plutot que de la lui faire recalculer garantit que
 * les deux cotes racontent la <b>meme</b> histoire — une barre verte ne peut
 * pas accompagner un texte qui parle de nuit trop courte.
 *
 * <p>Les bornes suivent les recommandations pour un adulte (7 a 9 heures), avec
 * deux paliers de part et d'autre plutot qu'un seul : « tu as dormi 6 h 45 » et
 * « tu as dormi 4 h » n'appellent pas le meme ton, ni le meme conseil.
 */
public enum SleepBand {

    /** Moins de 5 h — le seul palier ou le conseil devient une alerte. */
    CRITIQUE,

    /** De 5 h a 6 h — dette de sommeil installee. */
    INSUFFISANT,

    /** De 6 h a 7 h — un peu court, sans gravite. */
    COURT,

    /** De 7 h a 9 h — la cible. */
    OPTIMAL,

    /** De 9 h a 10 h — long, souvent une recuperation apres une dette. */
    LONG,

    /** Plus de 10 h — inhabituel de facon repetee. */
    EXCESSIF
}
