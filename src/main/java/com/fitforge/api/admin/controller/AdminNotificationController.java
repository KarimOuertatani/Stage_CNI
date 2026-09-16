package com.fitforge.api.admin.controller;

import com.fitforge.api.admin.dto.AdminNotificationResponse;
import com.fitforge.api.admin.entity.AdminNotification;
import com.fitforge.api.admin.repository.AdminNotificationRepository;
import com.fitforge.api.admin.service.AdminNotificationService;
import com.fitforge.api.common.dto.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.UUID;

/**
 * La cloche de la console d'administration.
 *
 * <h2>Pourquoi de la consultation periodique, et non du temps reel</h2>
 * Le projet dispose deja d'une infrastructure WebSocket/STOMP (le chat), et il
 * aurait ete techniquement possible d'y brancher un canal d'administration. Ce
 * n'est volontairement pas fait :
 * <ul>
 *   <li><b>Le besoin n'est pas temps reel.</b> Une candidature de coach attend
 *       de toute facon des heures avant d'etre examinee. La faire apparaitre en
 *       2 secondes plutot qu'en 30 ne change rien a personne.</li>
 *   <li><b>Le cout est reel.</b> Un second client STOMP, dans une autre pile
 *       technique, avec sa reconnexion et son authentification propres, est une
 *       surface entiere a maintenir pour ce gain nul.</li>
 *   <li><b>SSE n'aiderait pas.</b> L'{@code EventSource} des navigateurs
 *       n'accepte pas d'en-tete {@code Authorization} : il faudrait passer le
 *       jeton en parametre d'URL, donc l'ecrire dans les journaux d'acces.</li>
 * </ul>
 *
 * <p>La console interroge donc {@code /unread-count} a intervalle regulier --
 * une requete qui se resout par un index partiel portant sur les seules lignes
 * non lues, et qui reste donc constante quand la table grandit.
 */
@RestController
@RequestMapping("/api/v1/admin/notifications")
@RequiredArgsConstructor
@Tag(name = "Admin - Notifications", description = "Cloche de la console (role ADMIN)")
public class AdminNotificationController {

    private final AdminNotificationRepository repository;
    private final AdminNotificationService service;

    @GetMapping
    @Operation(summary = "Notifications, toutes ou seulement les non lues")
    public PageResponse<AdminNotificationResponse> list(
            @RequestParam(defaultValue = "false") boolean unreadOnly,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(Math.max(page, 0), Math.clamp(size, 1, 100));
        Page<AdminNotification> result = unreadOnly
                ? repository.findByReadAtIsNullOrderByCreatedAtDesc(pageable)
                : repository.findAllByOrderByCreatedAtDesc(pageable);
        return PageResponse.of(result, AdminNotificationResponse::from);
    }

    @GetMapping("/unread-count")
    @Operation(summary = "Nombre de notifications non lues (pastille de la cloche)")
    public Map<String, Long> unreadCount() {
        return Map.of("count", service.unreadCount());
    }

    @PostMapping("/{id}/read")
    @Operation(summary = "Marquer une notification comme lue")
    public Map<String, Long> markRead(@PathVariable UUID id) {
        service.markRead(id);
        return Map.of("count", service.unreadCount());
    }

    @PostMapping("/read-all")
    @Operation(summary = "Tout marquer comme lu")
    public Map<String, Long> markAllRead() {
        service.markAllRead();
        return Map.of("count", 0L);
    }
}
