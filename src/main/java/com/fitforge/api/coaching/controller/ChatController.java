package com.fitforge.api.coaching.controller;

import com.fitforge.api.coaching.dto.ChatMessageResponse;
import com.fitforge.api.coaching.dto.SendMessageRequest;
import com.fitforge.api.coaching.service.ChatService;
import com.fitforge.api.security.UserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * API du chat rattache a une relation de suivi. La livraison temps reel se fait
 * via WebSocket/STOMP ; ces routes REST assurent l'historique et l'envoi fiable.
 */
@RestController
@RequestMapping("/api/v1/coaching/{relationshipId}/messages")
@RequiredArgsConstructor
@Tag(name = "Chat", description = "Messagerie coach<->adherent")
public class ChatController {

    private final ChatService chatService;

    @GetMapping
    @Operation(summary = "Historique des messages (marque comme lus les recus)")
    public List<ChatMessageResponse> history(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID relationshipId) {
        return chatService.getMessages(me.getId(), relationshipId);
    }

    @PostMapping
    @Operation(summary = "Envoyer un message")
    public ResponseEntity<ChatMessageResponse> send(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID relationshipId,
            @Valid @RequestBody SendMessageRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(chatService.sendMessage(me.getId(), relationshipId, req));
    }

    @PostMapping("/read")
    @Operation(summary = "Marquer la conversation comme lue")
    public ResponseEntity<Void> markRead(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID relationshipId) {
        chatService.markRead(me.getId(), relationshipId);
        return ResponseEntity.noContent().build();
    }
}
