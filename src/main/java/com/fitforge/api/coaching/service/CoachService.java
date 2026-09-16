package com.fitforge.api.coaching.service;

import com.fitforge.api.coaching.dto.CoachProfileResponse;
import com.fitforge.api.coaching.dto.CoachSummaryResponse;
import com.fitforge.api.coaching.dto.RegisterCoachRequest;
import com.fitforge.api.coaching.dto.UpsertCoachProfileRequest;
import com.fitforge.api.coaching.entity.CoachProfile;
import com.fitforge.api.coaching.entity.CoachingRelationship;
import com.fitforge.api.coaching.mapper.CoachMapper;
import com.fitforge.api.coaching.repository.CoachProfileRepository;
import com.fitforge.api.coaching.repository.CoachingRelationshipRepository;
import com.fitforge.api.common.enums.CoachStatus;
import com.fitforge.api.common.enums.Role;
import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.security.JwtService;
import com.fitforge.api.user.dto.RegistrationResponse;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.repository.UserRepository;
import com.fitforge.api.user.service.EmailVerificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Gestion des coachs : inscription en tant que coach, edition du profil
 * professionnel, et consultation de l'annuaire / des profils par les adherents.
 */
@Service
@RequiredArgsConstructor
public class CoachService {

    private final CoachProfileRepository coachProfileRepo;
    private final CoachingRelationshipRepository relationshipRepo;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final CoachMapper mapper;
    private final EmailVerificationService verificationService;

    // ── Inscription coach ─────────────────────────────────────────

    /**
     * Cree un compte COACH <b>desactive</b> + son profil professionnel
     * (approuve d'office pour l'instant), puis envoie un code de verification
     * par email — exactement comme l'inscription adherent.
     *
     * <p>Aucun token n'est renvoye : le coach doit d'abord confirmer son
     * adresse via {@code POST /auth/verify-email}. Contrairement a l'adherent,
     * aucun UserProfile n'est cree.
     */
    @Transactional
    public RegistrationResponse registerCoach(RegisterCoachRequest req) {
        String email = req.email() == null ? "" : req.email().trim().toLowerCase();
        if (userRepository.existsByEmail(email)) {
            throw new BusinessException("Un compte existe deja avec cet email");
        }

        User user = User.builder()
                .email(email)
                .passwordHash(passwordEncoder.encode(req.password()))
                .fullName(req.fullName())
                .phoneNumber(req.phoneNumber())
                .role(Role.COACH)
                .enabled(false)               // active seulement apres verification
                .emailVerified(false)
                .build();
        user = userRepository.save(user);

        CoachProfile profile = CoachProfile.builder()
                .user(user)
                .headline(req.headline())
                .yearsExperience(req.yearsExperience())
                // DRAFT, et non APPROVED : le compte existe, mais le coach n'a
                // encore depose aucun justificatif. Il n'apparait dans aucun
                // annuaire et ne peut recevoir aucune demande tant que
                // l'administration n'a pas valide son dossier.
                .status(CoachStatus.DRAFT)
                .acceptingClients(true)
                .specialties(req.specialties() != null
                        ? new HashSet<>(req.specialties()) : new HashSet<>())
                .build();
        coachProfileRepo.save(profile);

        // Genere le code et declenche l'envoi (asynchrone).
        verificationService.issueCode(user);

        return new RegistrationResponse(
                user.getEmail(),
                EmailVerificationService.EXPIRY_MINUTES,
                "Un code de verification a ete envoye a " + user.getEmail());
    }

    // ── Profil du coach connecte ─────────────────────────────────

    @Transactional(readOnly = true)
    public CoachProfileResponse getMyProfile(UUID coachUserId) {
        CoachProfile p = loadByUser(coachUserId);
        return mapper.toProfile(p, null, null);
    }

    /**
     * Cree (si absent) ou met a jour le profil pro du coach connecte. Les listes
     * (certifs/formations/experiences) sont entierement remplacees.
     */
    @Transactional
    public CoachProfileResponse upsertMyProfile(UUID coachUserId, UpsertCoachProfileRequest req) {
        User user = userRepository.findById(coachUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));

        // Un adherent ne peut pas se doter d'un profil coach par cette route.
        if (user.getRole() != Role.COACH) {
            throw new BusinessException("Seul un compte coach peut editer un profil coach");
        }

        CoachProfile p = coachProfileRepo.findByUserId(coachUserId)
                .orElseGet(() -> CoachProfile.builder()
                        .user(user)
                        .status(CoachStatus.DRAFT)
                        .build());

        p.setHeadline(req.headline());
        p.setBio(req.bio());
        p.setYearsExperience(req.yearsExperience());
        p.setHourlyRate(req.hourlyRate());
        p.setCity(req.city());
        if (req.acceptingClients() != null) {
            p.setAcceptingClients(req.acceptingClients());
        }
        p.getSpecialties().clear();
        if (req.specialties() != null) {
            p.getSpecialties().addAll(req.specialties());
        }

        // orphanRemoval : on vide puis on reconstruit les listes.
        p.getCertifications().clear();
        p.getCertifications().addAll(mapper.certs(req.certifications(), p));
        p.getEducations().clear();
        p.getEducations().addAll(mapper.educations(req.educations(), p));
        p.getExperiences().clear();
        p.getExperiences().addAll(mapper.experiences(req.experiences(), p));

        // NOTE : le statut n'est JAMAIS touche ici. L'edition du profil et
        // l'etat de la candidature sont deux choses distinctes -- un coach
        // approuve qui corrige sa biographie ne repasse pas en examen, et un
        // coach refuse ne se revalide pas en reenregistrant son formulaire.
        // Les seules transitions autorisees passent par
        // CoachApplicationService.submit et AdminCoachApplicationService.

        CoachProfile saved = coachProfileRepo.save(p);
        return mapper.toProfile(saved, null, null);
    }

    // ── Annuaire / consultation par un adherent ──────────────────

    @Transactional(readOnly = true)
    public List<CoachSummaryResponse> getDirectory(UUID viewerId) {
        return coachProfileRepo
                .findByStatusOrderByRatingAverageDescRatingCountDesc(CoachStatus.APPROVED)
                .stream()
                .filter(p -> !p.getUser().getId().equals(viewerId))
                .map(mapper::toSummary)
                .toList();
    }

    /**
     * Fiche publique d'un coach, vue par un adherent.
     *
     * <p>Un profil non approuve est traite comme <b>inexistant</b> -- sauf s'il
     * s'agit du sien. Sans cette exception, un coach ne pourrait pas relire sa
     * propre fiche pendant l'examen de son dossier, ce qui est precisement le
     * moment ou il a le plus de raisons de la verifier.
     */
    @Transactional(readOnly = true)
    public CoachProfileResponse getCoachProfile(UUID viewerId, UUID coachUserId) {
        CoachProfile p = loadByUser(coachUserId);
        if (p.getStatus() != CoachStatus.APPROVED && !coachUserId.equals(viewerId)) {
            throw new ResourceNotFoundException("Profil coach introuvable");
        }
        Optional<CoachingRelationship> rel =
                relationshipRepo.findByCoachIdAndMemberId(coachUserId, viewerId);
        return mapper.toProfile(p,
                rel.map(CoachingRelationship::getStatus).orElse(null),
                rel.map(CoachingRelationship::getId).orElse(null));
    }

    private CoachProfile loadByUser(UUID coachUserId) {
        return coachProfileRepo.findByUserId(coachUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Profil coach introuvable"));
    }
}
