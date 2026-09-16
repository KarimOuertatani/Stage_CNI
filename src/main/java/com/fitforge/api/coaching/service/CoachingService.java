package com.fitforge.api.coaching.service;

import com.fitforge.api.coaching.dto.CoachDashboardResponse;
import com.fitforge.api.coaching.dto.CoachingRelationshipResponse;
import com.fitforge.api.coaching.entity.ChatMessage;
import com.fitforge.api.coaching.entity.CoachProfile;
import com.fitforge.api.coaching.entity.CoachingRelationship;
import com.fitforge.api.coaching.mapper.CoachMapper;
import com.fitforge.api.coaching.repository.ChatMessageRepository;
import com.fitforge.api.coaching.repository.CoachProfileRepository;
import com.fitforge.api.coaching.repository.CoachingRelationshipRepository;
import com.fitforge.api.common.enums.CoachStatus;
import com.fitforge.api.common.enums.CoachingStatus;
import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Relations de suivi adherent<->coach : demandes, acceptation/refus, listes
 * (cote coach = dashboard, cote adherent = mes coachs) et fin de suivi.
 */
@Service
@RequiredArgsConstructor
public class CoachingService {

    private final CoachingRelationshipRepository relationshipRepo;
    private final CoachProfileRepository coachProfileRepo;
    private final ChatMessageRepository chatRepo;
    private final UserRepository userRepository;
    private final CoachMapper mapper;

    // ── Cote adherent : demander un suivi ────────────────────────

    @Transactional
    public CoachingRelationshipResponse requestCoaching(UUID memberId, UUID coachUserId, String message) {
        if (memberId.equals(coachUserId)) {
            throw new BusinessException("Vous ne pouvez pas vous suivre vous-meme");
        }
        CoachProfile coachProfile = coachProfileRepo.findByUserId(coachUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Coach introuvable"));

        // Un coach non valide par l'administration n'existe pas, du point de
        // vue d'un adherent.
        //
        // Filtrer l'annuaire ne suffit PAS : cette route prend un identifiant
        // en parametre, et rien n'oblige un appelant a etre passe par
        // l'annuaire pour l'obtenir -- un ancien lien, une capture d'ecran, un
        // appel direct. Sans ce controle, un coach en cours d'examen (ou
        // refuse, ou suspendu) pourrait continuer a recevoir des adherents.
        //
        // 404 et non 403 : confirmer l'existence d'un compte en attente
        // d'examen renseignerait sur un dossier qui ne regarde que son
        // titulaire et l'administration. Meme raisonnement que pour la
        // presence (voir PresenceController).
        if (coachProfile.getStatus() != CoachStatus.APPROVED) {
            throw new ResourceNotFoundException("Coach introuvable");
        }
        if (!coachProfile.isAcceptingClients()) {
            throw new BusinessException("Ce coach n'accepte pas de nouveaux adherents pour le moment");
        }

        User member = userRepository.findById(memberId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));
        User coach = coachProfile.getUser();

        CoachingRelationship rel = relationshipRepo
                .findByCoachIdAndMemberId(coachUserId, memberId)
                .orElse(null);

        if (rel != null) {
            if (rel.getStatus() == CoachingStatus.PENDING) {
                throw new BusinessException("Une demande est deja en cours avec ce coach");
            }
            if (rel.getStatus() == CoachingStatus.ACCEPTED) {
                throw new BusinessException("Vous etes deja suivi par ce coach");
            }
            // DECLINED / ENDED : on relance une nouvelle demande sur la meme ligne.
            rel.setStatus(CoachingStatus.PENDING);
            rel.setRequestMessage(message);
            rel.setRespondedAt(null);
            rel.setEndedAt(null);
        } else {
            rel = CoachingRelationship.builder()
                    .coach(coach)
                    .member(member)
                    .status(CoachingStatus.PENDING)
                    .requestMessage(message)
                    .build();
        }

        return buildResponse(relationshipRepo.save(rel), memberId);
    }

    @Transactional(readOnly = true)
    public List<CoachingRelationshipResponse> getMemberRelationships(UUID memberId) {
        return relationshipRepo.findByMemberIdOrderByCreatedAtDesc(memberId).stream()
                .map(r -> buildResponse(r, memberId))
                .toList();
    }

    // ── Cote coach : dashboard + reponses ────────────────────────

    @Transactional(readOnly = true)
    public List<CoachingRelationshipResponse> getCoachRelationships(UUID coachUserId, CoachingStatus status) {
        List<CoachingRelationship> list = (status == null)
                ? relationshipRepo.findByCoachIdOrderByCreatedAtDesc(coachUserId)
                : relationshipRepo.findByCoachIdAndStatusOrderByCreatedAtDesc(coachUserId, status);
        return list.stream().map(r -> buildResponse(r, coachUserId)).toList();
    }

    @Transactional
    public CoachingRelationshipResponse respondToRequest(UUID coachUserId, UUID relationshipId, boolean accept) {
        CoachingRelationship rel = loadForCoach(coachUserId, relationshipId);
        if (rel.getStatus() != CoachingStatus.PENDING) {
            throw new BusinessException("Cette demande a deja ete traitee");
        }
        rel.setStatus(accept ? CoachingStatus.ACCEPTED : CoachingStatus.DECLINED);
        rel.setRespondedAt(Instant.now());
        return buildResponse(relationshipRepo.save(rel), coachUserId);
    }

    @Transactional(readOnly = true)
    public CoachDashboardResponse getDashboard(UUID coachUserId) {
        long pending = relationshipRepo
                .findByCoachIdAndStatusOrderByCreatedAtDesc(coachUserId, CoachingStatus.PENDING).size();
        long active = relationshipRepo.countByCoachIdAndStatus(coachUserId, CoachingStatus.ACCEPTED);
        long unread = relationshipRepo
                .findByCoachIdAndStatusOrderByCreatedAtDesc(coachUserId, CoachingStatus.ACCEPTED).stream()
                .mapToLong(r -> chatRepo.countByRelationshipIdAndReadAtIsNullAndSenderIdNot(r.getId(), coachUserId))
                .sum();
        return new CoachDashboardResponse(pending, active, unread);
    }

    // ── Commun : fin de suivi + detail ───────────────────────────

    @Transactional
    public CoachingRelationshipResponse endRelationship(UUID userId, UUID relationshipId) {
        CoachingRelationship rel = loadForParticipant(userId, relationshipId);
        if (rel.getStatus() != CoachingStatus.ACCEPTED && rel.getStatus() != CoachingStatus.PENDING) {
            throw new BusinessException("Ce suivi n'est pas actif");
        }
        rel.setStatus(CoachingStatus.ENDED);
        rel.setEndedAt(Instant.now());
        return buildResponse(relationshipRepo.save(rel), userId);
    }

    @Transactional(readOnly = true)
    public CoachingRelationshipResponse getRelationship(UUID userId, UUID relationshipId) {
        return buildResponse(loadForParticipant(userId, relationshipId), userId);
    }

    // ── Helpers ──────────────────────────────────────────────────

    /** Charge une relation en verifiant que l'utilisateur en est le coach. */
    CoachingRelationship loadForCoach(UUID coachUserId, UUID relationshipId) {
        CoachingRelationship rel = relationshipRepo.findById(relationshipId)
                .orElseThrow(() -> new ResourceNotFoundException("Demande introuvable"));
        if (!rel.getCoach().getId().equals(coachUserId)) {
            throw new ResourceNotFoundException("Demande introuvable");
        }
        return rel;
    }

    /** Charge une relation en verifiant que l'utilisateur en est participant. */
    CoachingRelationship loadForParticipant(UUID userId, UUID relationshipId) {
        CoachingRelationship rel = relationshipRepo.findById(relationshipId)
                .orElseThrow(() -> new ResourceNotFoundException("Suivi introuvable"));
        if (!rel.getCoach().getId().equals(userId) && !rel.getMember().getId().equals(userId)) {
            throw new ResourceNotFoundException("Suivi introuvable");
        }
        return rel;
    }

    /** Construit la reponse enrichie (apercu du dernier message + non-lus). */
    CoachingRelationshipResponse buildResponse(CoachingRelationship rel, UUID viewerId) {
        CoachProfile coachProfile = coachProfileRepo.findByUserId(rel.getCoach().getId()).orElse(null);
        String headline = coachProfile != null ? coachProfile.getHeadline() : null;

        ChatMessage last = chatRepo.findFirstByRelationshipIdOrderBySentAtDesc(rel.getId());
        long unread = chatRepo.countByRelationshipIdAndReadAtIsNullAndSenderIdNot(rel.getId(), viewerId);

        return new CoachingRelationshipResponse(
                rel.getId(),
                rel.getStatus(),
                rel.getRequestMessage(),
                rel.getCreatedAt(),
                rel.getRespondedAt(),
                mapper.toPersonRef(rel.getCoach(), headline),
                mapper.toPersonRef(rel.getMember(), null),
                mapper.previewOf(last),
                last != null ? last.getSentAt() : null,
                unread
        );
    }
}
