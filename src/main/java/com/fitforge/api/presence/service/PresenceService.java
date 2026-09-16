package com.fitforge.api.presence.service;

import com.fitforge.api.coaching.repository.CoachingRelationshipRepository;
import com.fitforge.api.common.enums.CoachingStatus;
import com.fitforge.api.presence.dto.PresenceResponse;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Registre de <b>presence temps reel</b> : qui est actuellement connecte.
 *
 * <p><b>Pourquoi la session WebSocket et pas une session HTTP ?</b> L'API est
 * volontairement {@code STATELESS} (JWT) : il n'existe aucune session HTTP, et
 * il ne faut surtout pas en creer. Un JWT ne se « deconnecte » jamais cote
 * serveur — un adherent qui ferme l'application resterait « en ligne » jusqu'a
 * l'expiration de son token, ce qui serait faux et invisible a corriger.
 *
 * <p>La session <b>STOMP</b>, elle, est un signal exact : elle nait au CONNECT,
 * meurt a la fermeture de l'app, du reseau ou de l'onglet, et Spring nous en
 * previent par evenement. C'est la seule source de verite utilisee ici.
 *
 * <p><b>Multi-appareils.</b> Un meme compte peut etre connecte sur plusieurs
 * appareils. On compte donc les <i>sessions</i> par utilisateur : il passe
 * hors ligne quand la <b>derniere</b> se ferme, pas la premiere.
 *
 * <p><b>Volatilite assumee.</b> Le registre vit en memoire : un redemarrage du
 * serveur remet tout le monde « hors ligne ». C'est correct — les clients se
 * reconnectent et se re-annoncent dans les secondes qui suivent. Pour que
 * l'affichage reste sensé entre-temps, {@code last_seen_at} est persiste en
 * base a chaque connexion ET a chaque deconnexion.
 *
 * <p><b>Confidentialite.</b> La presence n'est jamais publique : elle n'est
 * diffusee qu'aux personnes liees par un suivi {@code ACCEPTED}.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PresenceService {

    /** Destination STOMP privee des changements de presence. */
    public static final String PRESENCE_QUEUE = "/queue/presence";

    /** sessionId STOMP -> compte proprietaire (resolution a la deconnexion). */
    private final Map<String, UUID> sessionOwners = new ConcurrentHashMap<>();

    /** compte -> ses sessions actives (une par appareil/onglet). */
    private final Map<UUID, Set<String>> sessionsByUser = new ConcurrentHashMap<>();

    private final UserRepository userRepo;
    private final CoachingRelationshipRepository relationshipRepo;
    private final SimpMessagingTemplate messagingTemplate;

    // ── Evenements de session ────────────────────────────────────────

    /**
     * Enregistre une session WebSocket ouverte.
     *
     * <p>Ne previent les partenaires que si l'utilisateur vient reellement de
     * <b>passer</b> en ligne : ouvrir un second appareil ne doit declencher
     * aucune notification.
     */
    @Transactional
    public void userConnected(String sessionId, UUID userId) {
        AtomicBoolean cameOnline = new AtomicBoolean(false);

        if (sessionOwners.put(sessionId, userId) == null) {
            sessionsByUser.compute(userId, (id, sessions) -> {
                if (sessions == null) {
                    cameOnline.set(true);
                    sessions = ConcurrentHashMap.newKeySet();
                }
                sessions.add(sessionId);
                return sessions;
            });
        }

        touchLastSeen(userId);

        if (cameOnline.get()) {
            log.debug("Presence : {} est en ligne", userId);
            broadcast(userId, true);
        }
    }

    /**
     * Enregistre une session WebSocket fermee.
     *
     * <p>L'utilisateur ne passe hors ligne que lorsque sa <b>derniere</b>
     * session se termine.
     */
    @Transactional
    public void userDisconnected(String sessionId) {
        UUID userId = sessionOwners.remove(sessionId);
        if (userId == null) {
            return;   // session jamais authentifiee : rien a annoncer
        }

        AtomicBoolean wentOffline = new AtomicBoolean(false);
        sessionsByUser.computeIfPresent(userId, (id, sessions) -> {
            sessions.remove(sessionId);
            if (sessions.isEmpty()) {
                wentOffline.set(true);
                return null;   // retire l'entree : plus aucune session
            }
            return sessions;
        });

        // Toujours horodater : c'est ce « vu a » qui sera affiche ensuite.
        touchLastSeen(userId);

        if (wentOffline.get()) {
            log.debug("Presence : {} est hors ligne", userId);
            broadcast(userId, false);
        }
    }

    // ── Consultation ─────────────────────────────────────────────────

    /** Vrai si au moins une session WebSocket est ouverte pour ce compte. */
    public boolean isOnline(UUID userId) {
        return sessionsByUser.containsKey(userId);
    }

    /** Nombre de comptes actuellement connectes (supervision / diagnostic). */
    public int onlineCount() {
        return sessionsByUser.size();
    }

    /**
     * Etat de presence d'un compte, avec sa derniere activite connue.
     *
     * <p>{@code lastSeenAt} n'est renseigne que si l'utilisateur est hors
     * ligne : quand il est la, l'information n'a aucun interet et ne doit pas
     * etre exposee.
     */
    @Transactional(readOnly = true)
    public PresenceResponse presenceOf(UUID userId) {
        boolean online = isOnline(userId);
        Instant lastSeen = online
                ? null
                : userRepo.findById(userId).map(u -> u.getLastSeenAt()).orElse(null);
        return new PresenceResponse(userId, online, lastSeen);
    }

    /**
     * Presence de tous les interlocuteurs de chat d'un utilisateur.
     *
     * <p>Une seule requete pour toute la liste des conversations, plutot qu'un
     * appel par ligne.
     */
    @Transactional(readOnly = true)
    public List<PresenceResponse> presenceOfPartners(UUID userId) {
        return relationshipRepo.findPartnerIds(userId, CoachingStatus.ACCEPTED).stream()
                .map(this::presenceOf)
                .toList();
    }

    /**
     * Vrai si {@code viewer} a le droit de connaitre la presence de
     * {@code target} : soi-meme, ou un interlocuteur d'un suivi actif.
     */
    @Transactional(readOnly = true)
    public boolean canSee(UUID viewer, UUID target) {
        return viewer.equals(target)
                || relationshipRepo.areLinked(viewer, target, CoachingStatus.ACCEPTED);
    }

    // ── Interne ──────────────────────────────────────────────────────

    /**
     * Previent les interlocuteurs d'un suivi actif du changement de presence.
     *
     * <p>Diffusion ciblee, jamais un {@code /topic} public : la presence est
     * une donnee personnelle.
     */
    private void broadcast(UUID userId, boolean online) {
        PresenceResponse event = new PresenceResponse(
                userId, online, online ? null : Instant.now());

        for (UUID partnerId : relationshipRepo.findPartnerIds(userId, CoachingStatus.ACCEPTED)) {
            messagingTemplate.convertAndSendToUser(
                    partnerId.toString(), PRESENCE_QUEUE, event);
        }
    }

    /** Horodate l'activite sans charger l'entite (un simple UPDATE). */
    private void touchLastSeen(UUID userId) {
        try {
            userRepo.touchLastSeen(userId, Instant.now());
        } catch (RuntimeException e) {
            // La presence ne doit jamais faire echouer une connexion WebSocket.
            log.warn("Presence : horodatage impossible pour {} ({})", userId, e.getMessage());
        }
    }
}
