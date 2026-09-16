package com.fitforge.api.coaching.ai.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests du filet de securite sur les conseils « blessure ».
 *
 * <p>La consigne systeme interdit deja de citer un medicament. Ces tests
 * verifient la barriere qui la <b>rattrape</b> : celle qui ne depend pas d'un
 * modele probabiliste mais d'une comparaison de chaines.
 *
 * <p>Les faux positifs sont testes aussi sérieusement que les vrais : declencher
 * a tort remplacerait une bonne reponse par un texte generique, ce qui degrade
 * l'app pour rien.
 */
class SafetyGuardTest {

    private SafetyGuard guard;

    @BeforeEach
    void setUp() {
        guard = new SafetyGuard();
    }

    // ── Ce qui doit etre bloque ──────────────────────────────────────

    @ParameterizedTest
    @DisplayName("Une molecule ou une marque est detectee")
    @ValueSource(strings = {
            "Tu peux prendre de l'ibuprofene pour calmer la douleur.",
            "Un paracetamol suffira.",
            "Essaie du Doliprane 1000.",
            "Applique du Voltarene sur la zone.",
            "De l'aspirine peut aider.",
            "Le Advil est plus efficace ici.",
            "Un peu de cortisone reglera ca.",
    })
    void detectsMedications(String reply) {
        assertThat(guard.mentionsMedication(reply)).isTrue();
    }

    @ParameterizedTest
    @DisplayName("Une classe therapeutique est detectee, meme sans nom de produit")
    @ValueSource(strings = {
            "Prends un anti-inflammatoire pendant trois jours.",
            "Un antiinflammatoire suffira.",
            "Tu peux prendre un antalgique.",
            "Un antidouleur t'aidera a dormir.",
            "Essaie un myorelaxant.",
    })
    void detectsTherapeuticClasses(String reply) {
        // « prends un anti-inflammatoire » est exactement le conseil qu'on
        // refuse, meme s'il ne nomme aucun produit.
        assertThat(guard.mentionsMedication(reply)).isTrue();
    }

    @ParameterizedTest
    @DisplayName("Une forme ou un acte supposant une prescription est detecte")
    @ValueSource(strings = {
            "Une pommade anti-douleur sur la zone.",
            "Il te faudra une infiltration.",
            "Demande une ordonnance a ton medecin pour la posologie.",
            "Deux comprimes matin et soir.",
    })
    void detectsPrescriptionForms(String reply) {
        assertThat(guard.mentionsMedication(reply)).isTrue();
    }

    @ParameterizedTest
    @DisplayName("Le PLURIEL ne permet pas de passer")
    @ValueSource(strings = {
            "Prends des anti-inflammatoires pendant trois jours.",
            "Deux comprimes matin et soir.",
            "Des gelules d'ibuprofene.",
            "Les antalgiques t'aideront.",
            "Des corticoides seraient necessaires.",
            "Applique des pommades sur la zone.",
    })
    void detectsPlurals(String reply) {
        // Trou reel, trouve par les tests : un conseil se donne naturellement au
        // pluriel (« prends DES anti-inflammatoireS »). Sans le « s » optionnel
        // dans le motif, ces phrases — les plus probables — passaient toutes,
        // alors que leur singulier etait bien detecte.
        assertThat(guard.mentionsMedication(reply)).isTrue();
    }

    @Test
    @DisplayName("Les accents et la casse ne permettent pas de passer")
    void normalizesAccentsAndCase() {
        assertThat(guard.mentionsMedication("Prends de l'IBUPROFÈNE.")).isTrue();
        assertThat(guard.mentionsMedication("un ANTI-INFLAMMATOIRE")).isTrue();
        assertThat(guard.mentionsMedication("Anti Inflammatoire")).isTrue();
    }

    // ── Ce qui ne doit PAS etre bloque ───────────────────────────────

    @ParameterizedTest
    @DisplayName("Un conseil sain n'est pas bloque")
    @ValueSource(strings = {
            "Mets du froid 15 minutes, plusieurs fois par jour.",
            "Arrete le mouvement qui declenche la douleur et repose la zone.",
            "Surleve la jambe si elle gonfle.",
            "Reprends progressivement quand la douleur a disparu.",
            "Consulte un kinesitherapeute si ca persiste.",
            "Une creme solaire n'a rien a voir, mais l'echauffement compte.",
    })
    void allowsSafeAdvice(String reply) {
        assertThat(guard.mentionsMedication(reply)).isFalse();
    }

    @ParameterizedTest
    @DisplayName("« ains » ne declenche pas sur les mots qui le contiennent")
    @ValueSource(strings = {
            "Certains exercices sont a eviter pour le moment.",
            "Les prochains jours, alleger la charge.",
            "Des douleurs soudaines demandent un avis medical.",
            "Travaille les mains et les avant-bras autrement.",
    })
    void doesNotFalseTriggerOnSubstrings(String reply) {
        // Sans limites de mot, « ains » (la classe des anti-inflammatoires)
        // declencherait sur « certains », « prochains », « soudains »...
        assertThat(guard.mentionsMedication(reply)).isFalse();
    }

    @Test
    @DisplayName("Un texte vide ou nul ne declenche pas")
    void handlesEmptyInput() {
        assertThat(guard.mentionsMedication(null)).isFalse();
        assertThat(guard.mentionsMedication("")).isFalse();
        assertThat(guard.mentionsMedication("   ")).isFalse();
    }

    // ── Le repli ─────────────────────────────────────────────────────

    @Test
    @DisplayName("Le repli est un vrai conseil, et ne cite aucun medicament")
    void fallbackIsSafeAndUseful() {
        String fallback = guard.injuryFallback();

        // Le repli ne doit surtout pas declencher son propre garde-fou.
        assertThat(guard.mentionsMedication(fallback)).isFalse();
        // Ce n'est pas un message d'erreur : il donne les mesures sans risque.
        assertThat(fallback).contains("froid");
        assertThat(fallback).contains("repose").contains("progressivement");
        // Et il oriente toujours vers un professionnel.
        assertThat(fallback).contains("medecin");
    }

    // ── L'avertissement ──────────────────────────────────────────────

    @Test
    @DisplayName("L'avertissement est ajoute quand la reponse n'oriente pas")
    void appendsDisclaimerWhenMissing() {
        String reply = guard.withInjuryDisclaimer(
                "Mets du froid et evite de solliciter la zone.");

        assertThat(reply).contains("Mets du froid");
        assertThat(reply).contains(guard.injuryDisclaimer());
    }

    @Test
    @DisplayName("L'avertissement n'est pas repete si la reponse oriente deja")
    void doesNotDuplicateExistingRedirect() {
        // Le modele termine souvent de lui-meme par « consulte un medecin » :
        // le repeter juste apres donnerait une reponse qui bafouille.
        String original = "Mets du froid, et consulte un medecin si ca dure.";

        assertThat(guard.withInjuryDisclaimer(original)).isEqualTo(original);
    }

    @ParameterizedTest
    @DisplayName("Toutes les formes d'orientation sont reconnues")
    @ValueSource(strings = {
            "Va voir un medecin.",
            "Un kine pourra regarder ca.",
            "Consulte un professionnel de sante.",
            "Fais-toi examiner par un spécialiste.",
    })
    void recognizesAllRedirectWordings(String reply) {
        assertThat(guard.withInjuryDisclaimer(reply)).isEqualTo(reply);
    }
}
