package com.fitforge.api.coaching.ai.service;

import com.fitforge.api.coaching.ai.client.GeminiCoachClient;
import com.fitforge.api.coaching.ai.dto.AiCoachMessageResponse;
import com.fitforge.api.coaching.ai.entity.AiCoachMessage;
import com.fitforge.api.coaching.ai.repository.AiCoachMessageRepository;
import com.fitforge.api.common.enums.AiCoachRole;
import com.fitforge.api.common.enums.AiCoachTopic;
import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.domain.Pageable;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Tests du coach IA.
 *
 * <p>L'essentiel porte sur les <b>deux promesses</b> faites a l'adherent, celles
 * qu'un modele probabiliste ne peut pas garantir seul :
 * <ol>
 *   <li>le coach <b>ne parle que de sport</b>, et le refus est ecrit par
 *       l'application — donc identique et non negociable ;</li>
 *   <li>sur une blessure, il <b>ne cite jamais de medicament</b> et oriente
 *       toujours vers un professionnel.</li>
 * </ol>
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class AiCoachServiceTest {

    @Mock
    private AiCoachMessageRepository messageRepo;
    @Mock
    private UserRepository userRepo;
    @Mock
    private GeminiCoachClient gemini;
    @Mock
    private AiCoachProfileBriefer briefer;

    private AiCoachService service;
    private UUID userId;

    @BeforeEach
    void setUp() {
        // Le garde-fou de securite est le VRAI composant : c'est lui qu'on veut
        // exercer a travers le service.
        service = new AiCoachService(messageRepo, userRepo, gemini, briefer, new SafetyGuard());
        ReflectionTestUtils.setField(service, "maxMessagesPerHour", 40);

        userId = UUID.randomUUID();
        User user = new User();
        user.setId(userId);

        when(gemini.isConfigured()).thenReturn(true);
        when(userRepo.findById(userId)).thenReturn(Optional.of(user));
        when(messageRepo.findRecent(eq(userId), any(Pageable.class))).thenReturn(List.of());
        when(messageRepo.countUserMessagesSince(eq(userId), any(Instant.class))).thenReturn(0L);
        when(briefer.briefFor(userId)).thenReturn(null);
        // L'entite renvoyee telle quelle : on inspecte ce que le service a bati.
        when(messageRepo.save(any(AiCoachMessage.class))).thenAnswer(i -> i.getArgument(0));
    }

    private void modelAnswers(AiCoachTopic topic, String reply) {
        when(gemini.reply(anyList(), any(), anyString()))
                .thenReturn(new GeminiCoachClient.Answer(topic, reply));
    }

    /** Le message ASSISTANT effectivement persiste. */
    private AiCoachMessage savedReply() {
        ArgumentCaptor<AiCoachMessage> captor = ArgumentCaptor.forClass(AiCoachMessage.class);
        verify(messageRepo, times(2)).save(captor.capture());
        return captor.getAllValues().stream()
                .filter(m -> m.getRole() == AiCoachRole.ASSISTANT)
                .findFirst()
                .orElseThrow();
    }

    // ── Cas nominal ──────────────────────────────────────────────────

    @Test
    @DisplayName("Une question d'entrainement recoit la reponse du modele")
    void answersTrainingQuestion() {
        modelAnswers(AiCoachTopic.ENTRAINEMENT,
                "Pour les pectoraux, vise 3 a 4 series de 8 a 12 repetitions.");

        AiCoachMessageResponse reply =
                service.ask(userId, "Combien de series pour les pectoraux ?");

        assertThat(reply.role()).isEqualTo(AiCoachRole.ASSISTANT);
        assertThat(reply.topic()).isEqualTo(AiCoachTopic.ENTRAINEMENT);
        assertThat(reply.refused()).isFalse();
        assertThat(reply.content()).contains("3 a 4 series");
    }

    @Test
    @DisplayName("La question ET la reponse sont enregistrees, dans cet ordre")
    void persistsBothMessages() {
        modelAnswers(AiCoachTopic.NUTRITION, "Vise 1,6 g de proteines par kilo.");

        service.ask(userId, "Combien de proteines par jour ?");

        ArgumentCaptor<AiCoachMessage> captor = ArgumentCaptor.forClass(AiCoachMessage.class);
        verify(messageRepo, times(2)).save(captor.capture());

        assertThat(captor.getAllValues().get(0).getRole()).isEqualTo(AiCoachRole.USER);
        assertThat(captor.getAllValues().get(1).getRole()).isEqualTo(AiCoachRole.ASSISTANT);
    }

    @Test
    @DisplayName("Le profil de l'adherent est transmis au modele")
    void passesProfileToModel() {
        when(briefer.briefFor(userId)).thenReturn("- Objectif : prise masse");
        modelAnswers(AiCoachTopic.ENTRAINEMENT, "Ajoute du volume sur le haut du corps.");

        service.ask(userId, "Comment progresser ?");

        // Sans le profil, le coach repondrait ce qu'un moteur de recherche
        // repondrait : c'est cette transmission qui rend le conseil utilisable.
        verify(gemini).reply(anyList(), eq("- Objectif : prise masse"), anyString());
    }

    // ── Barriere de perimetre ────────────────────────────────────────

    @Test
    @DisplayName("Une demande hors sport est declinee avec NOTRE texte, pas celui du modele")
    void outOfScopeUsesOurOwnRefusal() {
        // Le modele a bien classe hors sujet — mais il a quand meme redige
        // quelque chose. Sa reponse ne doit pas etre utilisee.
        modelAnswers(AiCoachTopic.HORS_SUJET,
                "Pour ta copine, essaie de lui offrir des fleurs.");

        AiCoachMessageResponse reply =
                service.ask(userId, "Comment reconquerir ma copine ?");

        assertThat(reply.refused()).isTrue();
        assertThat(reply.topic()).isEqualTo(AiCoachTopic.HORS_SUJET);
        // Le point du test : le texte du modele est jete.
        assertThat(reply.content()).doesNotContain("fleurs");
        assertThat(reply.content()).contains("coach sportif");
        // Un refus ne doit pas etre un mur : il ramene vers ce qu'il sait faire.
        assertThat(reply.content()).contains("programme");
    }

    @Test
    @DisplayName("Le refus est identique a chaque tentative, donc non negociable")
    void refusalIsAlwaysTheSameText() {
        modelAnswers(AiCoachTopic.HORS_SUJET, "variante A");
        String first = service.ask(userId, "parle-moi de politique").content();

        modelAnswers(AiCoachTopic.HORS_SUJET, "variante B toute differente");
        String second = service.ask(userId, "allez, juste une fois").content();

        assertThat(second).isEqualTo(first);
    }

    @Test
    @DisplayName("Un modele bloque par ses filtres est traite comme hors perimetre")
    void blockedModelIsTreatedAsOutOfScope() {
        // Le client renvoie topic = HORS_SUJET et reply = null quand Gemini a
        // bloque la requete. Le service ne doit pas exploser dessus.
        modelAnswers(AiCoachTopic.HORS_SUJET, null);

        AiCoachMessageResponse reply = service.ask(userId, "message litigieux");

        assertThat(reply.refused()).isTrue();
        assertThat(reply.content()).contains("coach sportif");
    }

    // ── Barriere blessure ────────────────────────────────────────────

    @Test
    @DisplayName("Une reponse blessure citant un medicament est ENTIEREMENT remplacee")
    void medicationInInjuryReplyIsReplaced() {
        // La consigne systeme l'interdisait deja : ici elle a cede. C'est
        // exactement le cas que le garde-fou serveur existe pour rattraper.
        modelAnswers(AiCoachTopic.BLESSURE,
                "Prends de l'ibuprofene 400 mg trois fois par jour et repose-toi.");

        AiCoachMessageResponse reply = service.ask(userId, "j'ai mal au genou");

        assertThat(reply.content()).doesNotContain("ibuprofene");
        // On ne rafistole pas la phrase : « 400 mg trois fois par jour » sans le
        // nom du produit serait pire que l'original.
        assertThat(reply.content()).doesNotContain("400");
        // Et ce n'est pas un message d'erreur : le repli est un vrai conseil.
        assertThat(reply.content()).contains("froid");
        assertThat(reply.content()).contains("medecin");
        assertThat(reply.topic()).isEqualTo(AiCoachTopic.BLESSURE);
        assertThat(reply.refused()).isFalse();
    }

    @Test
    @DisplayName("Une reponse blessure saine recoit l'avertissement medical")
    void safeInjuryReplyGetsDisclaimer() {
        modelAnswers(AiCoachTopic.BLESSURE,
                "Arrete le mouvement qui declenche la douleur et mets du froid.");

        AiCoachMessageResponse reply = service.ask(userId, "mon epaule me gene");

        assertThat(reply.content()).contains("Arrete le mouvement");
        // Systematique : l'adherent doit voir a CHAQUE fois que ce n'est pas un
        // avis medical.
        assertThat(reply.content()).contains("pas medecin");
    }

    @Test
    @DisplayName("L'avertissement n'est pas ajoute si le modele oriente deja")
    void disclaimerNotDuplicated() {
        modelAnswers(AiCoachTopic.BLESSURE,
                "Mets du froid, et va voir un kinesitherapeute si ca persiste.");

        String content = service.ask(userId, "douleur au dos").content();

        assertThat(content).isEqualTo(
                "Mets du froid, et va voir un kinesitherapeute si ca persiste.");
    }

    @Test
    @DisplayName("Le garde-fou medicament ne s'applique qu'aux blessures")
    void medicationGuardIsScopedToInjuries() {
        // « gelule » est dans la liste, mais sur une question de complements
        // alimentaires ce n'est pas un conseil medical : on ne doit pas ecraser
        // une reponse nutrition legitime.
        modelAnswers(AiCoachTopic.NUTRITION,
                "La creatine en gelule ou en poudre, c'est equivalent.");

        String content = service.ask(userId, "creatine en poudre ou en gelule ?").content();

        assertThat(content).contains("equivalent");
    }

    // ── Contexte ─────────────────────────────────────────────────────

    @Test
    @DisplayName("Les derniers messages sont renvoyes au modele, du plus ancien au plus recent")
    void sendsHistoryInChronologicalOrder() {
        // Le repository rend les plus RECENTS d'abord : le service doit
        // reinverser, sinon le modele lit la conversation a l'envers.
        when(messageRepo.findRecent(eq(userId), any(Pageable.class))).thenReturn(List.of(
                message(AiCoachRole.ASSISTANT, "Vise 3 series."),
                message(AiCoachRole.USER, "Combien de series ?")));
        modelAnswers(AiCoachTopic.ENTRAINEMENT, "Pour les jambes, meme principe.");

        service.ask(userId, "et pour les jambes ?");

        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<GeminiCoachClient.Turn>> captor =
                ArgumentCaptor.forClass(List.class);
        verify(gemini).reply(captor.capture(), any(), anyString());

        List<GeminiCoachClient.Turn> turns = captor.getValue();
        assertThat(turns).hasSize(2);
        assertThat(turns.get(0).fromCoach()).isFalse();
        assertThat(turns.get(0).text()).isEqualTo("Combien de series ?");
        assertThat(turns.get(1).fromCoach()).isTrue();
    }

    private AiCoachMessage message(AiCoachRole role, String content) {
        return AiCoachMessage.builder().role(role).content(content).build();
    }

    // ── Garde-fous d'entree ──────────────────────────────────────────

    @Test
    @DisplayName("Une question vide est refusee avant tout appel")
    void blankQuestionIsRejected() {
        assertThatThrownBy(() -> service.ask(userId, "   "))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("Ecrivez");

        verify(gemini, never()).reply(anyList(), any(), anyString());
    }

    @Test
    @DisplayName("Sans cle configuree, le coach repond un message clair")
    void unconfiguredCoachIsExplicit() {
        when(gemini.isConfigured()).thenReturn(false);

        assertThatThrownBy(() -> service.ask(userId, "salut"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("pas disponible");

        verify(messageRepo, never()).save(any());
    }

    @Test
    @DisplayName("Le plafond horaire protege le quota partage")
    void hourlyCapIsEnforced() {
        when(messageRepo.countUserMessagesSince(eq(userId), any(Instant.class)))
                .thenReturn(40L);

        assertThatThrownBy(() -> service.ask(userId, "encore une question"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("quelques minutes");

        // La cle Gemini est partagee avec l'analyse photo et l'ajout vocal :
        // aucun appel ne doit partir une fois le plafond atteint.
        verify(gemini, never()).reply(anyList(), any(), anyString());
        verify(messageRepo, never()).save(any());
    }

    // ── Effacement ───────────────────────────────────────────────────

    @Test
    @DisplayName("Effacer le fil supprime tous les messages de l'adherent")
    void clearDeletesTheThread() {
        service.clear(userId);

        verify(messageRepo).deleteByUserId(userId);
    }
}
