package com.fitforge.api.coaching.ai.service;

import com.fitforge.api.coaching.ai.client.GeminiCoachClient;
import com.fitforge.api.coaching.ai.dto.AiCoachMessageResponse;
import com.fitforge.api.coaching.ai.entity.AiCoachMessage;
import com.fitforge.api.coaching.ai.repository.AiCoachMessageRepository;
import com.fitforge.api.common.enums.AiCoachRole;
import com.fitforge.api.common.enums.AiCoachTopic;
import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

/**
 * Le coach IA : un fil de discussion prive, borne au sport.
 *
 * <h2>Les trois barrieres de perimetre</h2>
 *
 * <p>Limiter un modele de langage a un sujet ne se fait pas en une seule fois.
 * Trois barrieres se relaient, de la plus souple a la plus rigide :
 *
 * <ol>
 *   <li><b>La consigne systeme</b> ({@link GeminiCoachClient}) enumere ce qui
 *       est autorise — pas ce qui est interdit, une liste d'interdits etant sans
 *       fin. Elle passe par {@code systemInstruction} et non par un message, ce
 *       qui la met hors de portee de la conversation.</li>
 *   <li><b>Le classement force</b> : le modele doit renvoyer un {@code topic}
 *       <b>avant</b> sa reponse. Il tranche donc le perimetre avant de rediger,
 *       au lieu de justifier apres coup ce qu'il vient d'ecrire.</li>
 *   <li><b>Le controle serveur</b> (ici) : c'est <b>l'application</b> qui ecrit
 *       le refus, pas le modele — le texte est donc identique a chaque fois et
 *       ne peut pas etre negocie. Et sur une blessure,
 *       {@link SafetyGuard} verifie qu'aucun medicament n'a ete cite.</li>
 * </ol>
 *
 * <p>Aucune n'est infaillible seule. Ensemble, elles font qu'un contournement
 * doit passer les trois — et la troisieme n'est pas un modele, c'est du code.
 *
 * <h2>Ce qui rend le coach utile</h2>
 *
 * <p>Deux choses, et elles comptent autant que le perimetre :
 * <ul>
 *   <li><b>la memoire</b> : les derniers tours sont renvoyes au modele, sinon
 *       « et pour les jambes ? » ne veut rien dire ;</li>
 *   <li><b>le profil</b> : objectif, niveau, materiel, blessures connues (voir
 *       {@link AiCoachProfileBriefer}). Sans lui, le coach repond ce qu'un
 *       moteur de recherche repondrait.</li>
 * </ul>
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AiCoachService {

    /**
     * Nombre de messages renvoyes au modele comme contexte.
     *
     * <p>12 messages, soit environ six echanges. Assez pour suivre un fil de
     * discussion, assez peu pour que le cout par message reste stable : tout
     * l'historique repart a chaque question, donc ce plafond borne directement
     * la facture et la latence.
     */
    private static final int CONTEXT_MESSAGES = 12;

    /** Fenetre du garde-fou de quota. */
    private static final Duration RATE_WINDOW = Duration.ofHours(1);

    /**
     * Le refus, ecrit par <b>l'application</b> et non par le modele.
     *
     * <p>Deux raisons de ne pas laisser le modele formuler son propre refus :
     * le texte serait different a chaque fois, et il serait negociable — un
     * adherent insistant obtiendrait des variantes de plus en plus souples.
     *
     * <p>Il ne dit pas seulement non : il <b>ramene vers ce qu'il sait faire</b>.
     * Un refus sec donne l'impression d'un outil casse ; celui-ci indique la
     * sortie.
     */
    private static final String OUT_OF_SCOPE_REPLY = """
            Je suis ton coach sportif : je ne parle que d'entrainement, de \
            nutrition et de blessures liees au sport. Sur ce sujet-la, je ne \
            peux pas t'aider.

            En revanche, dis-moi si tu veux qu'on regarde ton programme, tes \
            macros du jour, ou la technique d'un exercice.""";

    private final AiCoachMessageRepository messageRepo;
    private final UserRepository userRepo;
    private final GeminiCoachClient gemini;
    private final AiCoachProfileBriefer briefer;
    private final SafetyGuard safety;

    /**
     * Plafond de messages par heure et par adherent.
     *
     * <p>Chaque message coute un appel Gemini. Sans borne, un appui repete ou une
     * boucle cote client videraient le quota partage par <b>toute</b>
     * l'application — y compris l'analyse de photo et l'ajout vocal, qui
     * utilisent la meme cle.
     */
    @Value("${gemini.api.coach-max-messages-per-hour:40}")
    private int maxMessagesPerHour;

    // ── Lecture du fil ───────────────────────────────────────────────

    /** Le fil complet de l'adherent, du plus ancien au plus recent. */
    @Transactional(readOnly = true)
    public List<AiCoachMessageResponse> history(UUID userId) {
        return messageRepo.findByUserIdOrderByCreatedAtAsc(userId).stream()
                .map(this::toResponse)
                .toList();
    }

    /** Vrai si le coach IA est utilisable sur ce serveur (cle configuree). */
    public boolean isAvailable() {
        return gemini.isConfigured();
    }

    // ── Poser une question ───────────────────────────────────────────

    /**
     * Enregistre la question, obtient la reponse du coach, enregistre les deux.
     *
     * @return la reponse du coach (l'app connait deja la question)
     * @throws BusinessException question vide, plafond atteint, ou service
     *                           indisponible
     */
    @Transactional
    public AiCoachMessageResponse ask(UUID userId, String text) {
        String question = text == null ? "" : text.trim();
        if (question.isBlank()) {
            throw new BusinessException("Ecrivez votre question");
        }
        if (!gemini.isConfigured()) {
            throw new BusinessException(
                    "Le coach IA n'est pas disponible sur ce serveur pour le moment.");
        }
        enforceRateLimit(userId);

        User user = userRepo.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));

        // Le contexte est lu AVANT d'enregistrer la question : sinon elle
        // apparaitrait deux fois cote modele, dans l'historique et comme
        // message courant.
        List<GeminiCoachClient.Turn> context = contextFor(userId);
        String profileBrief = briefer.briefFor(userId);

        messageRepo.save(AiCoachMessage.builder()
                .user(user)
                .role(AiCoachRole.USER)
                .content(question)
                .build());

        GeminiCoachClient.Answer answer = gemini.reply(context, profileBrief, question);
        AiCoachMessage reply = buildReply(user, answer);

        return toResponse(messageRepo.save(reply));
    }

    /**
     * Construit la reponse a enregistrer, en appliquant les garde-fous.
     *
     * <p>C'est ici que le dernier mot revient a l'application.
     */
    private AiCoachMessage buildReply(User user, GeminiCoachClient.Answer answer) {
        // ── Hors perimetre : notre texte, pas le sien ────────────────
        if (answer.topic() == AiCoachTopic.HORS_SUJET || answer.reply() == null) {
            log.debug("Coach IA : demande hors perimetre declinee");
            return AiCoachMessage.builder()
                    .user(user)
                    .role(AiCoachRole.ASSISTANT)
                    .content(OUT_OF_SCOPE_REPLY)
                    .topic(AiCoachTopic.HORS_SUJET)
                    .refused(true)
                    .build();
        }

        String content = answer.reply();

        // ── Blessure : le sujet le plus encadre ─────────────────────
        if (answer.topic() == AiCoachTopic.BLESSURE) {
            if (safety.mentionsMedication(content)) {
                // La consigne l'interdisait deja ; elle a cede. On ne corrige
                // pas la phrase — retirer un mot d'un conseil medical produit
                // une phrase mutilee, parfois pire que l'originale. On remplace
                // toute la reponse.
                log.warn("Coach IA : reponse blessure ecartee, un medicament y etait cite");
                content = safety.injuryFallback();
            } else {
                content = safety.withInjuryDisclaimer(content);
            }
        }

        return AiCoachMessage.builder()
                .user(user)
                .role(AiCoachRole.ASSISTANT)
                .content(truncate(content))
                .topic(answer.topic())
                .refused(false)
                .build();
    }

    /** Efface le fil — « nouvelle conversation ». */
    @Transactional
    public void clear(UUID userId) {
        messageRepo.deleteByUserId(userId);
        log.debug("Coach IA : fil efface");
    }

    // ── Contexte ─────────────────────────────────────────────────────

    /**
     * Les derniers tours, du plus ancien au plus recent.
     *
     * <p>La requete lit les plus <b>recents</b> puis la liste est inversee :
     * quand on tronque une conversation, c'est la fin qu'il faut garder.
     *
     * <p>Les refus sont volontairement inclus. Les retirer donnerait au modele
     * l'impression que la question hors sujet n'a jamais ete posee, et
     * l'adherent qui insiste repartirait de zero a chaque tentative.
     */
    private List<GeminiCoachClient.Turn> contextFor(UUID userId) {
        List<AiCoachMessage> recent =
                messageRepo.findRecent(userId, PageRequest.of(0, CONTEXT_MESSAGES));

        List<AiCoachMessage> chronological = new ArrayList<>(recent);
        Collections.reverse(chronological);

        List<GeminiCoachClient.Turn> turns = new ArrayList<>(chronological.size());
        for (AiCoachMessage message : chronological) {
            turns.add(new GeminiCoachClient.Turn(
                    message.getRole() == AiCoachRole.ASSISTANT, message.getContent()));
        }
        return turns;
    }

    // ── Garde-fous ───────────────────────────────────────────────────

    private void enforceRateLimit(UUID userId) {
        long recent = messageRepo.countUserMessagesSince(
                userId, Instant.now().minus(RATE_WINDOW));
        if (recent >= maxMessagesPerHour) {
            throw new BusinessException(
                    "Tu as beaucoup echange avec le coach cette heure-ci. "
                            + "Reprends dans quelques minutes.");
        }
    }

    /**
     * Borne la reponse a la taille de la colonne.
     *
     * <p>{@code maxOutputTokens} limite deja le modele bien en dessous, et
     * l'avertissement blessure ne fait que quelques dizaines de caracteres. Ce
     * filet evite qu'une reponse inattendue fasse echouer l'insertion — perdre
     * la fin d'un message vaut mieux que perdre le message.
     */
    private String truncate(String content) {
        return content.length() <= 4000 ? content : content.substring(0, 4000);
    }

    // ── Mapping ──────────────────────────────────────────────────────

    private AiCoachMessageResponse toResponse(AiCoachMessage message) {
        return new AiCoachMessageResponse(
                message.getId(),
                message.getRole(),
                message.getContent(),
                message.getTopic(),
                message.isRefused(),
                message.getCreatedAt());
    }
}
