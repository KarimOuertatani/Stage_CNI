package com.fitforge.api.admin.dto;

import com.fitforge.api.admin.entity.AdminNotification;
import com.fitforge.api.common.enums.AdminNotificationType;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.Instant;
import java.util.UUID;

/** Une notification, telle que la cloche de la console l'affiche. */
@Schema(description = "Notification destinee a l'administration")
public record AdminNotificationResponse(
        UUID id,
        AdminNotificationType type,
        String title,
        String body,

        @Schema(description = "Identifiant de l'objet concerne, pour ouvrir la bonne fiche")
        UUID targetId,

        @Schema(description = "Null si la notification n'a pas encore ete lue")
        Instant readAt,
        Instant createdAt
) {
    public static AdminNotificationResponse from(AdminNotification n) {
        return new AdminNotificationResponse(
                n.getId(), n.getType(), n.getTitle(), n.getBody(),
                n.getTargetId(), n.getReadAt(), n.getCreatedAt());
    }
}
