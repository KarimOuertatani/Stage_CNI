package com.fitforge.api.coaching.ai.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.text.Normalizer;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Filet de securite <b>deterministe</b> sur les reponses du coach IA.
 *
 * <h2>Pourquoi ne pas se contenter de la consigne systeme</h2>
 *
 * <p>La consigne interdit deja explicitement de citer un medicament. Elle suffit
 * dans la quasi-totalite des cas — mais « la quasi-totalite » n'est pas un
 * niveau acceptable quand la consequence est qu'un adherent avale quelque chose
 * sur le conseil d'une application de fitness.
 *
 * <p>Un modele reste probabiliste : une formulation inattendue, une question
 * insistante, une mise a jour du modele cote fournisseur, et la consigne peut
 * ceder. Ce controle-ci, lui, ne cede pas : c'est une comparaison de chaines.
 *
 * <h2>Ce qu'il fait quand il declenche</h2>
 *
 * <p>Il ne <b>corrige pas</b> la reponse. Retirer un mot d'un texte medical
 * produit une phrase mutilee, parfois plus dangereuse que l'originale
 * (« prends 400 mg toutes les 6 heures » sans le nom du produit). La reponse est
 * donc <b>entierement remplacee</b> par un texte sur : reponse degradee, jamais
 * reponse douteuse.
 *
 * <h2>Normalisation</h2>
 *
 * <p>La detection travaille sur un texte sans accents et en minuscules :
 * « anti-inflammatoire », « Anti Inflammatoire » et « ANTI-INFLAMMATOIRE »
 * doivent tous etre vus. Les tirets et apostrophes sont ramenes a des espaces,
 * ce qui neutralise aussi les ecritures collees.
 */
@Component
@Slf4j
public class SafetyGuard {

    /**
     * Termes qui ne doivent pas apparaitre dans un conseil sur une blessure.
     *
     * <p>La liste vise trois familles :
     * <ul>
     *   <li><b>molecules et marques courantes</b> en France et au Maghreb — c'est
     *       ce qu'un modele propose spontanement ;</li>
     *   <li><b>classes therapeutiques</b> (anti-inflammatoire, antalgique...) :
     *       « prends un anti-inflammatoire » est exactement le conseil qu'on
     *       refuse, meme sans nom de produit ;</li>
     *   <li><b>formes et actes</b> (pommade, injection, ordonnance...), qui
     *       supposent une prescription.</li>
     * </ul>
     *
     * <p>Elle n'a pas besoin d'etre exhaustive pour etre utile : elle couvre ce
     * qu'un modele generique propose en pratique, et la consigne systeme couvre
     * le reste.
     */
    private static final List<String> MEDICATION_TERMS = List.of(
            // Molecules
            "ibuprofene", "paracetamol", "acetaminophene", "aspirine", "naproxene",
            "diclofenac", "ketoprofene", "codeine", "tramadol", "cortisone",
            "corticoide", "corticosteroide", "acide acetylsalicylique",
            // Marques
            "doliprane", "advil", "nurofen", "voltarene", "aspegic", "efferalgan",
            "dafalgan", "ketum", "profenid", "algifor",
            // Classes therapeutiques
            "anti inflammatoire", "antiinflammatoire", "ains", "antalgique",
            "analgesique", "antidouleur", "anti douleur", "myorelaxant",
            "decontractant musculaire",
            // Formes et actes supposant une prescription
            "pommade", "creme anti", "gel anti", "injection", "piqure",
            "infiltration", "ordonnance", "posologie", "comprime", "gelule");

    /**
     * Un motif unique plutot qu'une boucle de {@code contains}.
     *
     * <p><b>{@code \b} aux deux bouts.</b> Sans cela « ains » (la classe des
     * anti-inflammatoires) declencherait sur « certains », « prochains »,
     * « soudains »... Un faux positif ici n'est pas anodin : il remplacerait une
     * bonne reponse par un texte generique.
     *
     * <p><b>{@code s?} avant la limite finale — et c'est essentiel.</b> Un
     * conseil se donne naturellement au pluriel : « prends des
     * anti-inflammatoire<u>s</u> », « deux comprime<u>s</u> matin et soir ». Sans
     * ce {@code s} optionnel, ces phrases-la — les plus probables — passaient
     * toutes les deux au travers, alors que leur singulier etait bien detecte.
     */
    private static final Pattern MEDICATION_PATTERN = Pattern.compile(
            MEDICATION_TERMS.stream()
                    .map(term -> "\\b" + Pattern.quote(term) + "s?\\b")
                    .reduce((a, b) -> a + "|" + b)
                    .orElseThrow(),
            Pattern.CASE_INSENSITIVE);

    /** Accents et ligatures a neutraliser avant comparaison. */
    private static final Pattern DIACRITICS = Pattern.compile("\\p{M}+");
    /** Separateurs ramenes a l'espace : tirets, apostrophes, ponctuation collee. */
    private static final Pattern SEPARATORS = Pattern.compile("[-–—_'’/\\\\.,;:()\\[\\]]+");
    private static final Pattern SPACES = Pattern.compile("\\s+");

    /**
     * Vrai si le texte cite un medicament, une classe therapeutique ou une forme
     * supposant une prescription.
     */
    public boolean mentionsMedication(String text) {
        if (text == null || text.isBlank()) {
            return false;
        }
        return MEDICATION_PATTERN.matcher(normalize(text)).find();
    }

    /**
     * Reponse de repli quand un medicament a ete detecte.
     *
     * <p>Elle n'est pas un message d'erreur : c'est un <b>vrai conseil</b>, le
     * seul qu'une application de fitness soit legitime a donner sur une douleur.
     * L'adherent ne doit pas avoir l'impression d'etre tombe sur une panne.
     */
    public String injuryFallback() {
        return """
                Je ne peux pas te conseiller de traitement — ce n'est pas mon role \
                et ce serait risque sans examen.

                Ce que tu peux faire tout de suite, sans risque :
                • arrete le mouvement qui declenche la douleur et repose la zone
                • mets du froid 15 a 20 minutes, plusieurs fois par jour
                • surleve la zone si elle gonfle, et evite de la solliciter
                • reprends progressivement, seulement quand la douleur a disparu

                En attendant, on peut adapter ta seance pour travailler autre chose \
                sans toucher a cette zone.

                Si la douleur persiste plus de quelques jours, s'aggrave, ou si tu \
                as un gonflement, un craquement ou du mal a appuyer : consulte un \
                medecin ou un kinesitherapeute. Eux pourront regarder de pres.""";
    }

    /**
     * Avertissement ajoute a <b>toute</b> reponse portant sur une blessure.
     *
     * <p>Systematique, y compris quand la reponse du modele est irreprochable :
     * l'adherent doit voir a chaque fois que ce qu'il lit ne remplace pas un
     * avis medical. Une mention qui n'apparait qu'une fois sur trois n'informe
     * personne.
     */
    public String injuryDisclaimer() {
        return "Je ne suis pas medecin : si la douleur persiste ou s'aggrave, "
                + "fais-toi examiner par un professionnel de sante.";
    }

    /**
     * Ajoute l'avertissement, sauf s'il est <b>deja dit</b>.
     *
     * <p>Le modele termine souvent de lui-meme par « consulte un medecin » : le
     * repeter juste apres donnerait une reponse qui bafouille. On ne cherche pas
     * la formule exacte, mais le fait que l'orientation soit presente.
     */
    public String withInjuryDisclaimer(String reply) {
        String normalized = normalize(reply);
        boolean alreadyRedirects = normalized.contains("medecin")
                || normalized.contains("kine")
                || normalized.contains("professionnel de sante")
                || normalized.contains("specialiste");

        return alreadyRedirects ? reply : reply + "\n\n" + injuryDisclaimer();
    }

    /**
     * Texte comparable : minuscules, sans accents, separateurs ramenes a des
     * espaces simples.
     */
    private String normalize(String text) {
        String decomposed = Normalizer.normalize(text, Normalizer.Form.NFD);
        String withoutAccents = DIACRITICS.matcher(decomposed).replaceAll("");
        String spaced = SEPARATORS.matcher(withoutAccents).replaceAll(" ");
        return SPACES.matcher(spaced).replaceAll(" ").toLowerCase(Locale.ROOT).trim();
    }
}
