package com.fitforge.api.sleep.service;

import com.fitforge.api.common.enums.SleepBand;
import com.fitforge.api.sleep.entity.SleepEntry;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests du moteur d'analyse du sommeil.
 *
 * <p>Ils portent sur les trois endroits ou une regle ecrite peut se tromper en
 * silence, et ou personne ne s'en apercevrait avant longtemps :
 *
 * <ol>
 *   <li><b>Le passage de minuit.</b> Une nuit 23 h → 7 h est le cas le plus
 *       courant de tous, et une soustraction naive lui donne −16 heures.</li>
 *   <li><b>Le repli des heures de coucher.</b> Sans lui, 23 h 30 et 00 h 30
 *       paraissent distants de 23 heures, et tous ceux qui se couchent autour
 *       de minuit sont declares parfaitement irreguliers.</li>
 *   <li><b>Les bornes des tranches.</b> Elles decident du conseil affiche et de
 *       la couleur de la barre ; une borne decalee d'une minute donne un ecran
 *       qui se contredit lui-meme.</li>
 * </ol>
 */
class SleepAdvisorTest {

    private final SleepAdvisor advisor = new SleepAdvisor();

    // ═════════════════════════════════════════════════════════════════
    //  Duree : le passage de minuit
    // ═════════════════════════════════════════════════════════════════

    @Nested
    @DisplayName("Calcul de la duree")
    class DurationComputation {

        @ParameterizedTest(name = "{0} -> {1} = {2} min")
        @CsvSource({
                // Le cas normal : la nuit passe minuit.
                "23:00, 07:00, 480",
                "22:30, 06:15, 465",
                "00:30, 08:00, 450",
                "01:00, 09:30, 510",
                // La nuit ne passe pas minuit (sieste, travail de nuit).
                "02:00, 09:00, 420",
                "13:00, 15:00, 120",
                // Juste avant et juste apres minuit.
                "23:59, 00:01, 2",
                "00:00, 08:00, 480",
        })
        @DisplayName("les heures se soustraient correctement, minuit compris")
        void durationCrossesMidnight(String bed, String wake, int expected) {
            assertThat(SleepEntry.computeDuration(
                    LocalTime.parse(bed), LocalTime.parse(wake))).isEqualTo(expected);
        }

        @Test
        @DisplayName("coucher et lever identiques donnent un tour complet, pas zero")
        void sameTimeIsAFullDay() {
            // Une duree nulle passerait les bornes en silence et creerait une
            // nuit de 0 minute ; 24 h est refuse par le garde-fou du service.
            assertThat(SleepEntry.computeDuration(
                    LocalTime.of(23, 0), LocalTime.of(23, 0))).isEqualTo(1440);
        }
    }

    // ═════════════════════════════════════════════════════════════════
    //  Tranches
    // ═════════════════════════════════════════════════════════════════

    @Nested
    @DisplayName("Tranches de duree")
    class Bands {

        @ParameterizedTest(name = "{0} min -> {1}")
        @CsvSource({
                "60, CRITIQUE",
                "299, CRITIQUE",
                "300, INSUFFISANT",
                "359, INSUFFISANT",
                "360, COURT",
                "419, COURT",
                "420, OPTIMAL",
                "480, OPTIMAL",
                "540, OPTIMAL",
                "541, LONG",
                "600, LONG",
                "601, EXCESSIF",
                "900, EXCESSIF",
        })
        @DisplayName("les bornes tombent exactement ou elles doivent")
        void bandBoundaries(int minutes, SleepBand expected) {
            assertThat(advisor.bandOf(minutes)).isEqualTo(expected);
        }

        @Test
        @DisplayName("chaque tranche a un titre et un conseil non vides")
        void everyBandSpeaks() {
            // Un switch exhaustif ne garantit pas que les textes existent : une
            // branche qui renverrait une chaine vide compilerait tres bien et
            // afficherait un pop-up muet.
            for (int minutes : List.of(120, 330, 390, 480, 570, 700)) {
                assertThat(advisor.headlineFor(minutes)).isNotBlank();
                assertThat(advisor.adviceFor(minutes)).isNotBlank();
            }
        }

        @Test
        @DisplayName("le conseil d'une nuit optimale ne parle pas de manque")
        void optimalAdviceIsPositive() {
            String advice = advisor.adviceFor(480).toLowerCase();
            assertThat(advice).doesNotContain("allege").doesNotContain("trop court");
        }
    }

    // ═════════════════════════════════════════════════════════════════
    //  Score
    // ═════════════════════════════════════════════════════════════════

    @Nested
    @DisplayName("Score de la semaine")
    class Score {

        @Test
        @DisplayName("aucune nuit : pas de score, et surtout pas zero")
        void noNightsMeansNoScore() {
            // Zero se lirait comme « tu dors tres mal », alors que la verite est
            // « on ne sait pas ».
            assertThat(advisor.score(List.of())).isNull();
            assertThat(advisor.score(null)).isNull();
        }

        @Test
        @DisplayName("une semaine reguliere dans la cible frole les 100")
        void perfectWeekScoresHigh() {
            List<SleepEntry> week = week(
                    night("23:00", "07:00"), night("23:00", "07:00"),
                    night("23:00", "07:00"), night("23:00", "07:00"),
                    night("23:00", "07:00"), night("23:00", "07:00"),
                    night("23:00", "07:00"));

            assertThat(advisor.score(week)).isGreaterThanOrEqualTo(98);
        }

        @Test
        @DisplayName("des nuits trop courtes font tomber le score")
        void shortNightsScoreLow() {
            List<SleepEntry> week = week(
                    night("01:00", "05:30"), night("01:00", "05:30"),
                    night("01:00", "05:30"), night("01:00", "05:30"),
                    night("01:00", "05:30"));

            // 270 min de moyenne, soit 150 min sous la cible : la composante
            // duree s'effondre, la regularite sauve le reste.
            assertThat(advisor.score(week)).isLessThan(65);
        }

        @Test
        @DisplayName("a moyenne egale, l'irregularite coute des points")
        void irregularityCostsPoints() {
            // Les deux semaines font 480 min de moyenne. Seules les heures de
            // coucher changent : c'est exactement ce que la composante
            // regularite doit isoler.
            List<SleepEntry> steady = week(
                    night("23:00", "07:00"), night("23:00", "07:00"),
                    night("23:00", "07:00"), night("23:00", "07:00"));

            List<SleepEntry> chaotic = week(
                    night("21:00", "05:00"), night("02:00", "10:00"),
                    night("22:00", "06:00"), night("03:00", "11:00"));

            assertThat(advisor.averageMinutes(steady))
                    .isEqualTo(advisor.averageMinutes(chaotic));
            assertThat(advisor.score(chaotic)).isLessThan(advisor.score(steady));
        }

        @Test
        @DisplayName("se coucher autour de minuit n'est pas de l'irregularite")
        void midnightWrapIsNotIrregularity() {
            // 23 h 30 et 00 h 30 sont distants d'une heure. Sans le repli sur
            // un axe du soir, ils paraitraient distants de 23 heures et cette
            // semaine serait notee comme totalement chaotique.
            List<SleepEntry> aroundMidnight = week(
                    night("23:30", "07:30"), night("00:30", "08:30"),
                    night("23:45", "07:45"), night("00:15", "08:15"));

            assertThat(advisor.score(aroundMidnight)).isGreaterThanOrEqualTo(90);
        }

        @Test
        @DisplayName("une longue nuit n'annule pas quatre nuits courtes")
        void oneLongNightDoesNotCancelShortOnes() {
            // LE test de la composante duree. Les deux semaines ont EXACTEMENT
            // la meme moyenne (408 min) et des heures de coucher identiques :
            // seule la repartition change.
            //
            //   dette   : 4 nuits de 6 h rattrapees par une nuit de 10 h
            //   regulier: 5 nuits de 6 h 48
            //
            // Noter la moyenne au lieu de noter chaque nuit leur donnerait la
            // meme note — alors que la premiere semaine est une dette
            // accumulee, vecue comme epuisante, et la seconde un rythme un peu
            // court mais tenu.
            List<SleepEntry> debt = week(
                    night("00:00", "06:00"), night("00:00", "06:00"),
                    night("00:00", "06:00"), night("00:00", "06:00"),
                    night("00:00", "10:00"));

            List<SleepEntry> steady = week(
                    night("00:00", "06:48"), night("00:00", "06:48"),
                    night("00:00", "06:48"), night("00:00", "06:48"),
                    night("00:00", "06:48"));

            assertThat(advisor.averageMinutes(debt))
                    .isEqualTo(advisor.averageMinutes(steady));
            assertThat(advisor.score(debt)).isLessThan(advisor.score(steady));
        }

        @Test
        @DisplayName("une semaine de nuits courtes ne decroche pas « excellente »")
        void shortWeekIsNotCalledExcellent() {
            // Le titre commente le score et s'affiche juste au-dessus des
            // conseils : s'ils se contredisent, c'est l'ecran entier qui perd
            // sa credibilite.
            List<SleepEntry> shortWeek = week(
                    night("00:30", "06:30"), night("01:00", "06:45"),
                    night("23:45", "06:30"), night("00:15", "06:20"),
                    night("23:00", "09:00"));

            Integer score = advisor.score(shortWeek);
            assertThat(advisor.weeklyHeadline(score)).isNotEqualTo("Semaine excellente");
        }

        @Test
        @DisplayName("sous trois nuits, la regularite n'est pas comptee")
        void regularityNeedsThreeNights() {
            // Deux nuits ideales mais a des heures tres differentes : noter
            // l'irregularite ici reviendrait a noter l'usage de l'application,
            // pas le sommeil.
            List<SleepEntry> two = week(night("21:00", "05:00"), night("03:00", "11:00"));

            assertThat(advisor.score(two)).isGreaterThanOrEqualTo(98);
        }

        @Test
        @DisplayName("dormir douze heures n'est pas mieux que d'en dormir cinq")
        void tooMuchIsPenalisedToo() {
            List<SleepEntry> tooLong = week(
                    night("22:00", "10:00"), night("22:00", "10:00"),
                    night("22:00", "10:00"), night("22:00", "10:00"));

            assertThat(advisor.score(tooLong)).isLessThan(85);
        }

        @Test
        @DisplayName("le score reste dans 0..100 meme sur des valeurs extremes")
        void scoreStaysInRange() {
            List<SleepEntry> awful = week(
                    night("05:00", "05:30"), night("06:00", "06:30"),
                    night("04:00", "04:20"), night("23:00", "23:30"));

            Integer score = advisor.score(awful);
            assertThat(score).isNotNull().isBetween(0, 100);
        }
    }

    // ═════════════════════════════════════════════════════════════════
    //  Conseils de la semaine
    // ═════════════════════════════════════════════════════════════════

    @Nested
    @DisplayName("Conseils de la semaine")
    class WeeklyTips {

        @Test
        @DisplayName("jamais plus de trois conseils")
        void neverMoreThanThree() {
            // Une liste de huit conseils ne se lit pas et ne se hierarchise
            // pas : l'adherent ne sait plus par quoi commencer.
            List<SleepEntry> chaotic = week(
                    night("21:00", "02:00"), night("03:00", "07:00"),
                    night("22:30", "04:00"), night("01:00", "05:00"));

            assertThat(advisor.weeklyTips(chaotic, 7)).hasSizeLessThanOrEqualTo(3);
        }

        @Test
        @DisplayName("une semaine vide invite a saisir plutot que de rester muette")
        void emptyWeekStillSpeaks() {
            List<String> tips = advisor.weeklyTips(List.of(), 7);

            assertThat(tips).hasSize(1);
            assertThat(tips.get(0)).contains("Aucune nuit");
        }

        @Test
        @DisplayName("une semaine complete ne reproche pas de nuits manquantes")
        void completeWeekHasNoCoverageTip() {
            List<SleepEntry> full = week(
                    night("23:00", "07:00"), night("23:00", "07:00"),
                    night("23:00", "07:00"), night("23:00", "07:00"),
                    night("23:00", "07:00"), night("23:00", "07:00"),
                    night("23:00", "07:00"));

            assertThat(advisor.weeklyTips(full, 7))
                    .noneMatch(tip -> tip.contains("Il manque"));
        }

        @Test
        @DisplayName("le titre suit le score, et existe meme sans donnees")
        void headlineFollowsScore() {
            assertThat(advisor.weeklyHeadline(null)).isNotBlank();
            assertThat(advisor.weeklyHeadline(95)).isEqualTo("Semaine excellente");
            assertThat(advisor.weeklyHeadline(75)).isEqualTo("Bonne semaine");
            assertThat(advisor.weeklyHeadline(10)).isEqualTo("Semaine a redresser");
        }
    }

    // ═════════════════════════════════════════════════════════════════
    //  Rattrapage du week-end
    // ═════════════════════════════════════════════════════════════════

    @Nested
    @DisplayName("Ecart week-end / semaine")
    class WeekendCatchUp {

        @Test
        @DisplayName("detecte le rattrapage du week-end")
        void detectsCatchUp() {
            // Lundi 2026-07-27 : les nuits du samedi et du dimanche sont les
            // 1er et 2 aout.
            List<SleepEntry> entries = new ArrayList<>();
            entries.add(nightOn(LocalDate.of(2026, 7, 27), "00:30", "06:30")); // lundi, 6 h
            entries.add(nightOn(LocalDate.of(2026, 7, 28), "00:30", "06:30")); // mardi, 6 h
            entries.add(nightOn(LocalDate.of(2026, 8, 1), "23:00", "09:00"));  // samedi, 10 h
            entries.add(nightOn(LocalDate.of(2026, 8, 2), "23:00", "09:00"));  // dimanche, 10 h

            assertThat(advisor.weekendCatchUpMinutes(entries)).isEqualTo(240);
        }

        @Test
        @DisplayName("sans week-end ou sans semaine, l'ecart n'a pas de sens")
        void needsBothGroups() {
            List<SleepEntry> weekdaysOnly = List.of(
                    nightOn(LocalDate.of(2026, 7, 27), "23:00", "07:00"),
                    nightOn(LocalDate.of(2026, 7, 28), "23:00", "07:00"));

            assertThat(advisor.weekendCatchUpMinutes(weekdaysOnly)).isNull();
            assertThat(advisor.weekendCatchUpMinutes(List.of())).isNull();
        }
    }

    // ── Outillage ────────────────────────────────────────────────────

    /** Une nuit sans date precise — pour les tests qui n'en dependent pas. */
    private SleepEntry night(String bed, String wake) {
        return nightOn(LocalDate.of(2026, 7, 27), bed, wake);
    }

    private SleepEntry nightOn(LocalDate date, String bed, String wake) {
        LocalTime bedTime = LocalTime.parse(bed);
        LocalTime wakeTime = LocalTime.parse(wake);
        return SleepEntry.builder()
                .sleepDate(date)
                .bedTime(bedTime)
                .wakeTime(wakeTime)
                .durationMinutes(SleepEntry.computeDuration(bedTime, wakeTime))
                .build();
    }

    /** Des nuits sur des jours consecutifs a partir du lundi 2026-07-27. */
    private List<SleepEntry> week(SleepEntry... nights) {
        List<SleepEntry> entries = new ArrayList<>(nights.length);
        LocalDate monday = LocalDate.of(2026, 7, 27);
        for (int i = 0; i < nights.length; i++) {
            nights[i].setSleepDate(monday.plusDays(i));
            entries.add(nights[i]);
        }
        return entries;
    }
}
