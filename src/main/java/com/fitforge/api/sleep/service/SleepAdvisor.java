package com.fitforge.api.sleep.service;

import com.fitforge.api.common.enums.SleepBand;
import com.fitforge.api.sleep.entity.SleepEntry;
import org.springframework.stereotype.Component;

import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

/**
 * L'analyse du sommeil : tranches, score et conseils. <b>Sans modele de
 * langage.</b>
 *
 * <h2>Pourquoi aucune IA ici</h2>
 *
 * <p>Ce module aurait pu appeler Gemini comme le generateur de programme. Il ne
 * le fait pas, et c'est un choix, pas une economie :
 *
 * <ul>
 *   <li><b>La regle est connue.</b> « 6 h 30, c'est un peu court » ne demande
 *       aucune interpretation : c'est une comparaison a un intervalle publie.
 *       Faire trancher un modele probabiliste une question qui a une reponse
 *       fixe, c'est ajouter de l'incertitude a un endroit ou il n'y en avait
 *       pas.</li>
 *   <li><b>Le conseil doit etre instantane.</b> Il s'affiche dans le pop-up,
 *       juste apres l'enregistrement, alors que l'adherent vient d'ouvrir son
 *       application. Une seconde d'attente y serait deja de trop ; trente le
 *       rendraient inutilisable.</li>
 *   <li><b>Il doit etre identique a lui-meme.</b> Deux nuits de 6 h 30 doivent
 *       recevoir le meme conseil. Un modele en produirait deux formulations,
 *       et l'adherent y lirait un changement d'avis qui n'existe pas.</li>
 *   <li><b>Il ne coute rien.</b> Le quota Gemini est partage avec le coach IA,
 *       l'analyse de photo, l'ajout vocal et la generation de programme. Une
 *       consommation quotidienne, par adherent, pour une comparaison
 *       d'intervalles les priverait tous les quatre.</li>
 * </ul>
 *
 * <p>Le sommeil est le cas ou une regle ecrite bat un modele. Le programme
 * d'entrainement est l'inverse : composer un decoupage n'a pas de reponse
 * unique, et c'est pour ca qu'il appelle Gemini.
 */
@Component
public class SleepAdvisor {

    // ── Bornes des tranches, en minutes ──────────────────────────────
    private static final int CRITIQUE_MAX = 300;      // 5 h
    private static final int INSUFFISANT_MAX = 360;   // 6 h
    private static final int COURT_MAX = 420;         // 7 h
    private static final int OPTIMAL_MAX = 540;       // 9 h
    private static final int LONG_MAX = 600;          // 10 h

    /** La cible : 7 h a 9 h. Aucun malus de duree a l'interieur. */
    private static final int IDEAL_MIN = COURT_MAX;
    private static final int IDEAL_MAX = OPTIMAL_MAX;

    // ── Ponderation du score ─────────────────────────────────────────
    /** Points maximum pour la duree moyenne. */
    private static final int DURATION_POINTS = 70;
    /** Points maximum pour la regularite des heures de coucher. */
    private static final int REGULARITY_POINTS = 30;

    /**
     * Minutes d'ecart a la cible qui coutent un point.
     *
     * <p>Quatre minutes par point : une heure de moins que la cible coute 15
     * points, deux heures en coutent 30. Assez raide pour que l'ecart se voie,
     * assez doux pour qu'une nuit courte ne reduise pas le score a zero — un
     * score qui s'effondre au premier ecart ne se regarde plus.
     */
    private static final double MINUTES_PER_POINT = 4.0;

    /**
     * Nombre de nuits en dessous duquel la regularite n'est pas calculee.
     *
     * <p>Avec une ou deux nuits, la « regularite » ne mesure rien : elle
     * mesurerait l'usage de l'application, pas le sommeil. Le score se rabat
     * alors entierement sur la duree (voir {@link #score}).
     */
    private static final int MIN_NIGHTS_FOR_REGULARITY = 3;

    /** Ecart moyen des heures de coucher, en minutes, au-dela duquel la note de regularite est nulle. */
    private static final double REGULARITY_ZERO_AT_MINUTES = 90.0;

    /**
     * Heure de reference pour comparer des couchers.
     *
     * <p>Sans elle, 23 h 30 et 00 h 30 sont distants de 23 heures en arithmetique
     * naive, alors qu'une heure les separe — et toute personne qui se couche
     * autour de minuit passerait pour parfaitement irreguliere. On replie donc
     * les heures sur un axe qui commence a 18 h : 18 h vaut 0, minuit vaut 360,
     * 4 h du matin vaut 600.
     */
    private static final LocalTime EVENING_ORIGIN = LocalTime.of(18, 0);

    // ═════════════════════════════════════════════════════════════════
    //  Tranche
    // ═════════════════════════════════════════════════════════════════

    /** La tranche a laquelle appartient une duree. */
    public SleepBand bandOf(int minutes) {
        if (minutes < CRITIQUE_MAX) {
            return SleepBand.CRITIQUE;
        }
        if (minutes < INSUFFISANT_MAX) {
            return SleepBand.INSUFFISANT;
        }
        if (minutes < COURT_MAX) {
            return SleepBand.COURT;
        }
        if (minutes <= OPTIMAL_MAX) {
            return SleepBand.OPTIMAL;
        }
        if (minutes <= LONG_MAX) {
            return SleepBand.LONG;
        }
        return SleepBand.EXCESSIF;
    }

    // ═════════════════════════════════════════════════════════════════
    //  Le conseil immediat — celui du pop-up
    // ═════════════════════════════════════════════════════════════════

    /**
     * Ce que le coach dit juste apres la saisie, en une ou deux phrases.
     *
     * <p>Il est <b>rattache a l'entrainement</b>, et pas au sommeil en general.
     * « Dors davantage » est un conseil de magazine ; « en dessous de 6 h, ta
     * force baisse des la premiere serie » dit a l'adherent pourquoi ca le
     * concerne, lui, dans cette application-la.
     *
     * <p>Aucun ton culpabilisant, meme sur la tranche critique : quelqu'un qui
     * vient de mal dormir le sait deja, et un reproche au reveil est le plus sur
     * moyen de ne plus jamais rouvrir le formulaire.
     */
    public String adviceFor(int minutes) {
        return switch (bandOf(minutes)) {
            case CRITIQUE -> "Nuit tres courte. Aujourd'hui, allege : garde les "
                    + "mouvements que tu maitrises, baisse les charges, et oublie "
                    + "les series jusqu'a l'echec. Le manque de sommeil degrade la "
                    + "coordination avant meme la force.";
            case INSUFFISANT -> "Un peu juste. Tu peux t'entrainer, mais vise la "
                    + "technique plutot que le record du jour — et couche-toi "
                    + "30 minutes plus tot ce soir, c'est le reglage le plus "
                    + "rentable.";
            case COURT -> "Presque la cible. Une demi-heure de plus et tu y es. "
                    + "C'est pendant le sommeil profond que le muscle se repare : "
                    + "ces 30 minutes valent plus qu'une serie de plus.";
            case OPTIMAL -> "Excellente nuit. C'est exactement la zone ou la "
                    + "recuperation et la force sont au mieux — profite-en pour "
                    + "placer ta seance la plus exigeante.";
            case LONG -> "Longue nuit. Souvent le signe que tu rattrapes une "
                    + "dette accumulee : si ca se repete, avance ton heure de "
                    + "coucher en semaine plutot que de rattraper d'un coup.";
            case EXCESSIF -> "Nuit tres longue. Ponctuellement c'est de la "
                    + "recuperation. Si ca dure plusieurs jours avec une fatigue "
                    + "qui ne passe pas, parles-en a un professionnel de sante.";
        };
    }

    /** Titre court affiche au-dessus du conseil. */
    public String headlineFor(int minutes) {
        return switch (bandOf(minutes)) {
            case CRITIQUE -> "Nuit tres courte";
            case INSUFFISANT -> "Nuit insuffisante";
            case COURT -> "Nuit un peu courte";
            case OPTIMAL -> "Nuit ideale";
            case LONG -> "Longue nuit";
            case EXCESSIF -> "Nuit tres longue";
        };
    }

    // ═════════════════════════════════════════════════════════════════
    //  Le score de la semaine
    // ═════════════════════════════════════════════════════════════════

    /**
     * Note 0-100 d'une serie de nuits, ou {@code null} si aucune n'est saisie.
     *
     * <p>Deux composantes, parce que la duree seule ment : deux adherents a 7 h
     * de moyenne ne dorment pas pareil si l'un fait sept nuits de 7 h et l'autre
     * alterne 4 h et 10 h. La regularite pese 30 points sur 100 — assez pour
     * qu'elle compte, pas assez pour qu'une semaine chahutee efface une bonne
     * duree.
     *
     * <p>La composante duree elle-meme est calculee <b>nuit par nuit puis
     * moyennee</b>, et non sur la moyenne de la semaine
     * ({@link #durationRatio}). Sans cela, une nuit de 10 h annulerait
     * arithmetiquement quatre nuits de 6 h et le score dirait « excellent »
     * d'une semaine que l'adherent a vecue comme epuisante.
     *
     * <p><b>En dessous de trois nuits</b>, la regularite n'est pas calculee et
     * la duree occupe les 100 points. Noter l'irregularite de quelqu'un qui a
     * saisi deux nuits reviendrait a noter son usage de l'application.
     */
    public Integer score(List<SleepEntry> entries) {
        if (entries == null || entries.isEmpty()) {
            return null;
        }

        double durationRatio = durationRatio(entries);

        if (entries.size() < MIN_NIGHTS_FOR_REGULARITY) {
            return (int) Math.round(durationRatio * 100);
        }

        double regularityRatio = regularityRatio(entries);
        double points = durationRatio * DURATION_POINTS
                + regularityRatio * REGULARITY_POINTS;
        return (int) Math.round(points);
    }

    /** Duree moyenne, en minutes, arrondie a l'entier le plus proche. */
    public int averageMinutes(List<SleepEntry> entries) {
        return (int) Math.round(entries.stream()
                .mapToInt(SleepEntry::getDurationMinutes)
                .average()
                .orElse(0));
    }

    /**
     * Part des points de duree obtenue, entre 0 et 1.
     *
     * <h3>Chaque nuit est notee, puis les notes sont moyennees</h3>
     *
     * <p>Et non l'inverse. La difference est tout sauf theorique : une semaine
     * de quatre nuits a 6 h et d'une nuit a 10 h a <b>exactement</b> la meme
     * moyenne qu'une semaine de cinq nuits a 6 h 48. Noter la moyenne donnerait
     * la meme note aux deux — alors que la premiere est une dette accumulee
     * rattrapee d'un coup, et la seconde un rythme regulier un peu court.
     *
     * <p>C'est precisement le defaut qu'on reproche a la moyenne dans la note
     * de {@link #score} ; le corriger pour les heures de coucher et pas pour
     * les durees aurait laisse la moitie du probleme en place. En notant nuit
     * par nuit, la longue nuit ne peut plus <b>annuler</b> les courtes : elle
     * est elle-meme penalisee de s'eloigner de la cible.
     */
    private double durationRatio(List<SleepEntry> entries) {
        return entries.stream()
                .mapToDouble(entry -> nightRatio(entry.getDurationMinutes()))
                .average()
                .orElse(0);
    }

    /**
     * Note d'une seule nuit, entre 0 et 1.
     *
     * <p>Plein tarif dans la cible, decroissance lineaire de part et d'autre.
     * L'ecart est compte <b>en valeur absolue</b> : dormir douze heures n'est
     * pas mieux que d'en dormir cinq, meme si l'intuition dit le contraire.
     */
    private double nightRatio(int minutes) {
        int distance = 0;
        if (minutes < IDEAL_MIN) {
            distance = IDEAL_MIN - minutes;
        } else if (minutes > IDEAL_MAX) {
            distance = minutes - IDEAL_MAX;
        }
        double lost = distance / MINUTES_PER_POINT;
        return Math.max(0, Math.min(1, (DURATION_POINTS - lost) / DURATION_POINTS));
    }

    /**
     * Part des points de regularite obtenue, entre 0 et 1.
     *
     * <p>Mesuree sur l'<b>heure de coucher</b> et non sur la duree : c'est elle
     * qui pilote l'horloge interne, et c'est la seule des deux sur laquelle
     * l'adherent a vraiment la main. On prend l'ecart moyen a l'heure de coucher
     * habituelle ; un ecart moyen d'une heure et demie annule la composante.
     */
    private double regularityRatio(List<SleepEntry> entries) {
        List<Integer> bedTimes = entries.stream()
                .map(e -> minutesFromEveningOrigin(e.getBedTime()))
                .toList();

        double mean = bedTimes.stream().mapToInt(Integer::intValue).average().orElse(0);
        double meanDeviation = bedTimes.stream()
                .mapToDouble(minute -> Math.abs(minute - mean))
                .average()
                .orElse(0);

        return Math.max(0, 1 - meanDeviation / REGULARITY_ZERO_AT_MINUTES);
    }

    /**
     * Heure de coucher repliee sur un axe qui commence a 18 h.
     *
     * <p>18 h vaut 0, minuit vaut 360, 4 h du matin vaut 600. Sans ce repliage,
     * 23 h 30 et 00 h 30 paraitraient distants de 23 heures et quiconque se
     * couche autour de minuit serait declare parfaitement irregulier.
     *
     * <p>Une heure de coucher en pleine journee (14 h, par exemple) retombe sur
     * un point eloigne de l'axe, ce qui est le comportement voulu : c'est bien
     * un rythme atypique.
     */
    private int minutesFromEveningOrigin(LocalTime bedTime) {
        int minutes = bedTime.getHour() * 60 + bedTime.getMinute();
        int origin = EVENING_ORIGIN.getHour() * 60;
        return minutes >= origin ? minutes - origin : minutes + (24 * 60 - origin);
    }

    // ═════════════════════════════════════════════════════════════════
    //  Les conseils de la semaine
    // ═════════════════════════════════════════════════════════════════

    /**
     * Deux a trois conseils sur la semaine ecoulee.
     *
     * <p><b>Trois au maximum</b>, et c'est une regle, pas une limite technique :
     * une liste de huit conseils ne se lit pas, et surtout elle ne se hierarchise
     * pas — l'adherent ne sait plus par quoi commencer. On garde ce qui change
     * quelque chose, dans l'ordre ou ca compte.
     *
     * <p>Ils portent sur la <b>semaine</b> et non sur une nuit : le conseil de
     * nuit existe deja dans le pop-up ({@link #adviceFor}). Repeter le meme
     * texte a deux endroits donnerait l'impression d'un module qui n'a qu'une
     * chose a dire.
     */
    public List<String> weeklyTips(List<SleepEntry> entries, int expectedNights) {
        List<String> tips = new ArrayList<>(3);

        if (entries == null || entries.isEmpty()) {
            tips.add("Aucune nuit enregistree cette semaine. Une seule saisie par "
                    + "jour suffit a faire apparaitre tes tendances.");
            return tips;
        }

        int average = averageMinutes(entries);

        // 1. La duree d'abord : c'est ce qui pese le plus dans le score, donc
        //    ce sur quoi agir en premier.
        tips.add(switch (bandOf(average)) {
            case CRITIQUE, INSUFFISANT -> "Ta moyenne est sous les 6 heures. "
                    + "Avance ton coucher de 15 minutes tous les trois jours : "
                    + "un decalage progressif tient, un changement brutal non.";
            case COURT -> "Tu tournes juste sous la cible. Une demi-heure de plus "
                    + "par nuit suffirait a te faire passer dans la zone ou la "
                    + "recuperation est optimale.";
            case OPTIMAL -> "Ta duree moyenne est dans la cible. C'est le socle "
                    + "sur lequel tout le reste repose — garde ce rythme.";
            case LONG, EXCESSIF -> "Tes nuits sont longues. Si tu te reveilles "
                    + "quand meme fatigue, c'est la qualite du sommeil qu'il faut "
                    + "regarder, pas sa duree.";
        });

        // 2. La regularite ensuite, si elle est mesurable et qu'elle cloche.
        if (entries.size() >= MIN_NIGHTS_FOR_REGULARITY) {
            double regularity = regularityRatio(entries);
            if (regularity < 0.6) {
                tips.add("Tes heures de coucher varient beaucoup. Un horaire "
                        + "stable, meme imparfait, vaut mieux qu'un horaire ideal "
                        + "une nuit sur deux : c'est la regularite qui cale "
                        + "l'horloge interne.");
            } else if (regularity > 0.85 && tips.size() < 3) {
                tips.add("Tes heures de coucher sont tres stables. C'est ce qui "
                        + "rend l'endormissement plus rapide et le reveil moins "
                        + "penible.");
            }
        }

        // 3. La couverture en dernier : c'est un conseil sur l'usage de
        //    l'application, il ne doit jamais passer avant un conseil de fond.
        if (tips.size() < 3 && entries.size() < expectedNights) {
            int missing = expectedNights - entries.size();
            tips.add("Il manque " + missing + " nuit" + (missing > 1 ? "s" : "")
                    + " cette semaine. Plus l'historique est complet, plus la "
                    + "moyenne et le score refletent ce que tu vis reellement.");
        }

        return tips;
    }

    /**
     * Le titre de la semaine, deduit du score.
     *
     * <p>Il commente le <b>score</b> et non la duree : c'est lui qui est affiche
     * juste a cote, et deux libelles qui ne parlent pas de la meme chose au meme
     * endroit se contredisent tot ou tard.
     */
    public String weeklyHeadline(Integer score) {
        if (score == null) {
            return "Pas encore de donnees";
        }
        // Seuils volontairement exigeants sur le haut. « Excellente » doit
        // vouloir dire excellente : une semaine ou presque toutes les nuits
        // sont dans la cible ET a des heures stables. Trop bas, le titre finit
        // par contredire le conseil affiche juste en dessous — c'est
        // exactement ce qui arrivait avec un seuil a 85, ou une semaine de
        // quatre nuits courtes decrochait « Semaine excellente » pendant que
        // le conseil disait « tu tournes sous la cible ».
        if (score >= 88) {
            return "Semaine excellente";
        }
        if (score >= 72) {
            return "Bonne semaine";
        }
        if (score >= 55) {
            return "Semaine correcte";
        }
        if (score >= 35) {
            return "Semaine difficile";
        }
        return "Semaine a redresser";
    }

    /**
     * Ecart entre les nuits de week-end et celles de semaine, en minutes.
     *
     * <p>Renvoie {@code null} si l'un des deux groupes est vide. Un ecart
     * important est le signe d'une dette accumulee en semaine et rattrapee le
     * week-end — un motif tres courant, et invisible sur la seule moyenne.
     */
    public Integer weekendCatchUpMinutes(List<SleepEntry> entries) {
        if (entries == null || entries.isEmpty()) {
            return null;
        }
        List<SleepEntry> weekend = entries.stream().filter(this::isWeekend).toList();
        List<SleepEntry> weekdays = entries.stream().filter(e -> !isWeekend(e)).toList();

        if (weekend.isEmpty() || weekdays.isEmpty()) {
            return null;
        }
        return averageMinutes(weekend) - averageMinutes(weekdays);
    }

    /** Une nuit de week-end est celle dont le <b>reveil</b> tombe samedi ou dimanche. */
    private boolean isWeekend(SleepEntry entry) {
        DayOfWeek day = entry.getSleepDate().getDayOfWeek();
        return day == DayOfWeek.SATURDAY || day == DayOfWeek.SUNDAY;
    }
}
