package com.fitforge.api.coaching.service;

import com.fitforge.api.coaching.dto.ChatMessageResponse;
import com.fitforge.api.coaching.dto.SendMessageRequest;
import com.fitforge.api.coaching.dto.TypingEvent;
import com.fitforge.api.coaching.entity.ChatMessage;
import com.fitforge.api.coaching.entity.CoachingRelationship;
import com.fitforge.api.coaching.mapper.CoachMapper;
import com.fitforge.api.coaching.repository.ChatMessageRepository;
import com.fitforge.api.common.enums.CoachingStatus;
import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.user.entity.User;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Chat entre coach et adherent, rattache a une relation de suivi ACCEPTED.
 * Persiste l'historique et pousse les messages en temps reel via WebSocket/STOMP
 * sur la file privee du destinataire ({@code /user/queue/messages}).
 */
@Service
@RequiredArgsConstructor
public class ChatService {

    private final ChatMessageRepository chatRepo;
    private final CoachingService coachingService;
    private final CoachMapper mapper;
    private final SimpMessagingTemplate messagingTemplate;

    /** Destination STOMP privee (prefixee /user/{id} par Spring). */
    public static final String USER_QUEUE = "/queue/messages";

    /** Destination STOMP privee des signaux « en train d'ecrire ». */
    public static final String TYPING_QUEUE = "/queue/typing";

    /** Historique complet d'un fil (marque aussi les messages recus comme lus). */
    @Transactional
    public List<ChatMessageResponse> getMessages(UUID userId, UUID relationshipId) {
        coachingService.loadForParticipant(userId, relationshipId); // controle d'acces
        chatRepo.markAsRead(relationshipId, userId, Instant.now());
        return chatRepo.findByRelationshipIdOrderBySentAtAsc(relationshipId).stream()
                .map(mapper::toMessage)
                .toList();
    }

    /** Envoie un message (texte et/ou piece jointe) : persiste puis pousse au destinataire. */
    @Transactional
    public ChatMessageResponse sendMessage(UUID senderId, UUID relationshipId, SendMessageRequest req) {
        CoachingRelationship rel = coachingService.loadForParticipant(senderId, relationshipId);
        if (rel.getStatus() != CoachingStatus.ACCEPTED) {
            throw new BusinessException("Le suivi doit etre actif pour echanger des messages");
        }

        boolean senderIsCoach = rel.getCoach().getId().equals(senderId);
        User sender = senderIsCoach ? rel.getCoach() : rel.getMember();
        User recipient = senderIsCoach ? rel.getMember() : rel.getCoach();

        String content = (req.content() != null && !req.content().isBlank()) ? req.content().trim() : null;

        ChatMessage msg = ChatMessage.builder()
                .relationship(rel)
                .sender(sender)
                .content(content)
                .attachmentUrl(req.attachmentUrl())
                .attachmentKind(req.attachmentKind())
                .attachmentName(req.attachmentName())
                .attachmentSize(req.attachmentSize())
                .attachmentDurationSec(req.attachmentDurationSec())
                .build();
        // saveAndFlush : force l'INSERT tout de suite pour que @CreationTimestamp
        // (sentAt) soit renseigne dans la reponse. Sans flush, sentAt serait null
        // et le message s'afficherait mal ordonne cote client.
        ChatMessageResponse response = mapper.toMessage(chatRepo.saveAndFlush(msg));

        // Push temps reel vers la file privee du destinataire.
        messagingTemplate.convertAndSendToUser(
                recipient.getId().toString(), USER_QUEUE, response);

        return response;
    }

    /** Marque comme lus les messages recus par l'utilisateur dans ce fil. */
    @Transactional
    public void markRead(UUID userId, UUID relationshipId) {
        coachingService.loadForParticipant(userId, relationshipId);
        chatRepo.markAsRead(relationshipId, userId, Instant.now());
    }

    /**
     * Relaie un signal « en train d'ecrire » vers le seul interlocuteur du fil.
     *
     * <p><b>L'auteur vient du principal STOMP</b>, jamais du message recu : un
     * client malveillant ne peut donc pas se faire passer pour quelqu'un
     * d'autre. L'appartenance au fil est verifiee comme pour un envoi normal.
     *
     * <p>Rien n'est persiste : une frappe n'a de valeur que dans l'instant. Si
     * le destinataire n'est pas connecte, le signal est perdu — c'est le
     * comportement voulu.
     */
    @Transactional(readOnly = true)
    public void relayTyping(UUID senderId, UUID relationshipId, boolean typing) {
        CoachingRelationship rel = coachingService.loadForParticipant(senderId, relationshipId);
        if (rel.getStatus() != CoachingStatus.ACCEPTED) {
            return;   // fil en lecture seule : aucun signal a relayer
        }

        boolean senderIsCoach = rel.getCoach().getId().equals(senderId);
        UUID recipientId = senderIsCoach ? rel.getMember().getId() : rel.getCoach().getId();

        messagingTemplate.convertAndSendToUser(
                recipientId.toString(), TYPING_QUEUE,
                new TypingEvent(relationshipId, senderId, typing));
    }
}
