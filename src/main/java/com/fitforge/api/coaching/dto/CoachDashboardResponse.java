package com.fitforge.api.coaching.dto;

import io.swagger.v3.oas.annotations.media.Schema;

/** Indicateurs du tableau de bord coach. */
@Schema(description = "Tableau de bord coach (compteurs)")
public record CoachDashboardResponse(
        long pendingRequests,
        long activeClients,
        long unreadMessages
) {}
