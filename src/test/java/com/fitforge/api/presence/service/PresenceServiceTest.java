package com.fitforge.api.presence.service;

import com.fitforge.api.coaching.repository.CoachingRelationshipRepository;
import com.fitforge.api.common.enums.CoachingStatus;
import com.fitforge.api.presence.dto.PresenceResponse;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Tests du registre de presence.
 *
 * <p>Ce qui est verrouille ici, c'est le <b>comptage des sessions</b> : c'est
 * la seule vraie subtilite du service. Un utilisateur connecte sur deux
 * appareils ne doit etre annonce en ligne qu'une fois, et ne repasser hors
 * ligne qu'a la fermeture de la <b>derniere</b> session — un bug ici afficherait
 * « hors ligne » a quelqu'un qui est parfaitement present.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PresenceServiceTest {

    private static final UUID ME = UUID.randomUUID();
    private static final UUID PARTNER = UUID.randomUUID();

    @Mock
    private UserRepository userRepo;
    @Mock
    private CoachingRelationshipRepository relationshipRepo;
    @Mock
    private SimpMessagingTemplate messagingTemplate;

    @InjectMocks
    private PresenceService presence;

    @BeforeEach
    void setUp() {
        when(relationshipRepo.findPartnerIds(ME, CoachingStatus.ACCEPTED))
                .thenReturn(List.of(PARTNER));
    }

    // ── Comptage des sessions ────────────────────────────────────────

    @Test
    @DisplayName("La premiere session met en ligne et previent les interlocuteurs")
    void firstSessionAnnouncesOnline() {
        presence.userConnected("session-1", ME);

        assertThat(presence.isOnline(ME)).isTrue();
        verify(messagingTemplate).convertAndSendToUser(
                eq(PARTNER.toString()), eq(PresenceService.PRESENCE_QUEUE), any(Object.class));
    }

    @Test
    @DisplayName("Un second appareil ne redeclenche aucune annonce")
    void secondDeviceDoesNotReAnnounce() {
        presence.userConnected("telephone", ME);
        presence.userConnected("tablette", ME);

        assertThat(presence.isOnline(ME)).isTrue();
        // Une seule annonce, pas deux : l'interlocuteur ne doit pas voir
        // clignoter le statut a chaque appareil ouvert.
        verify(messagingTemplate, times(1)).convertAndSendToUser(
                eq(PARTNER.toString()), eq(PresenceService.PRESENCE_QUEUE), any(Object.class));
    }

    @Test
    @DisplayName("Fermer UN appareil sur deux laisse l'utilisateur en ligne")
    void closingOneOfTwoDevicesKeepsOnline() {
        presence.userConnected("telephone", ME);
        presence.userConnected("tablette", ME);

        presence.userDisconnected("telephone");

        assertThat(presence.isOnline(ME)).isTrue();
        // Une seule annonce au total (celle de la mise en ligne) : aucune
        // annonce « hors ligne » ne doit partir ici.
        verify(messagingTemplate, times(1)).convertAndSendToUser(
                eq(PARTNER.toString()), eq(PresenceService.PRESENCE_QUEUE), any(Object.class));
    }

    @Test
    @DisplayName("La derniere session fermee met hors ligne")
    void lastSessionAnnouncesOffline() {
        presence.userConnected("telephone", ME);
        presence.userConnected("tablette", ME);

        presence.userDisconnected("telephone");
        presence.userDisconnected("tablette");

        assertThat(presence.isOnline(ME)).isFalse();
        // 2 annonces : une en ligne, une hors ligne.
        verify(messagingTemplate, times(2)).convertAndSendToUser(
                eq(PARTNER.toString()), eq(PresenceService.PRESENCE_QUEUE), any(Object.class));
    }

    @Test
    @DisplayName("Une session inconnue ne declenche rien")
    void unknownSessionIsIgnored() {
        presence.userDisconnected("session-jamais-vue");

        assertThat(presence.onlineCount()).isZero();
        verify(messagingTemplate, never()).convertAndSendToUser(
                any(String.class), any(String.class), any(Object.class));
    }

    @Test
    @DisplayName("Une meme session annoncee deux fois ne compte qu'une fois")
    void duplicateConnectIsIdempotent() {
        presence.userConnected("session-1", ME);
        presence.userConnected("session-1", ME);

        presence.userDisconnected("session-1");

        assertThat(presence.isOnline(ME)).isFalse();
    }

    // ── Horodatage ───────────────────────────────────────────────────

    @Test
    @DisplayName("Connexion et deconnexion horodatent la derniere activite")
    void touchesLastSeenOnBothEvents() {
        presence.userConnected("session-1", ME);
        presence.userDisconnected("session-1");

        verify(userRepo, times(2)).touchLastSeen(eq(ME), any(Instant.class));
    }

    @Test
    @DisplayName("Un echec d'horodatage ne casse jamais la connexion")
    void survivesTouchFailure() {
        org.mockito.Mockito.doThrow(new RuntimeException("base indisponible"))
                .when(userRepo).touchLastSeen(any(UUID.class), any(Instant.class));

        presence.userConnected("session-1", ME);

        assertThat(presence.isOnline(ME)).isTrue();
    }

    // ── Consultation ─────────────────────────────────────────────────

    @Test
    @DisplayName("En ligne : la derniere activite n'est pas exposee")
    void onlineHidesLastSeen() {
        presence.userConnected("session-1", ME);

        PresenceResponse response = presence.presenceOf(ME);

        assertThat(response.online()).isTrue();
        assertThat(response.lastSeenAt()).isNull();
    }

    @Test
    @DisplayName("Hors ligne : la derniere activite vient de la base")
    void offlineExposesLastSeen() {
        Instant seen = Instant.now().minus(20, ChronoUnit.MINUTES);
        User user = User.builder().id(PARTNER).lastSeenAt(seen).build();
        when(userRepo.findById(PARTNER)).thenReturn(Optional.of(user));

        PresenceResponse response = presence.presenceOf(PARTNER);

        assertThat(response.online()).isFalse();
        assertThat(response.lastSeenAt()).isEqualTo(seen);
    }

    // ── Confidentialite ──────────────────────────────────────────────

    @Test
    @DisplayName("On voit toujours sa propre presence")
    void alwaysSeesOwnPresence() {
        assertThat(presence.canSee(ME, ME)).isTrue();
    }

    @Test
    @DisplayName("On ne voit la presence d'autrui que via un suivi actif")
    void seesPartnerOnlyWhenLinked() {
        when(relationshipRepo.areLinked(ME, PARTNER, CoachingStatus.ACCEPTED)).thenReturn(true);
        assertThat(presence.canSee(ME, PARTNER)).isTrue();

        UUID stranger = UUID.randomUUID();
        when(relationshipRepo.areLinked(ME, stranger, CoachingStatus.ACCEPTED)).thenReturn(false);
        assertThat(presence.canSee(ME, stranger)).isFalse();
    }
}
