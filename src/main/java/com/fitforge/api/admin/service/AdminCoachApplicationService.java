package com.fitforge.api.admin.service;

import com.fitforge.api.admin.dto.AdminCoachApplicationDetail;
import com.fitforge.api.admin.dto.AdminCoachApplicationSummary;
import com.fitforge.api.coaching.dto.CertificationDto;
import com.fitforge.api.coaching.dto.CoachDocumentResponse;
import com.fitforge.api.coaching.dto.EducationDto;
import com.fitforge.api.coaching.dto.ExperienceDto;
import com.fitforge.api.coaching.entity.CoachDocument;
import com.fitforge.api.coaching.entity.CoachProfile;
import com.fitforge.api.coaching.repository.CoachProfileRepository;
import com.fitforge.api.common.dto.PageResponse;
import com.fitforge.api.common.enums.CoachStatus;
import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.repository.UserRepository;
import com.fitforge.api.user.service.EmailService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Examen des candidatures de coach par l'administration.
 *
 * <h2>C'est le point ou une decision humaine devient un fait</h2>
 * Tout le reste du parcours coach (inscription, depot de justificatifs,
 * soumission) est reversible et sans consequence pour les adherents. Les trois
 * methodes de decision ci-dessous sont les seules qui rendent un coach visible
 * -- ou l'en retirent.
 *
 * <h2>Les transitions sont verifiees, jamais supposees</h2>
 * Chaque decision commence par verifier l'etat de depart. Une console peut
 * toujours envoyer une action sur un dossier qu'un autre onglet vient de
 * traiter : sans ce controle, deux administrateurs travaillant en meme temps
 * pourraient approuver puis refuser le meme dossier, et le coach recevrait deux
 * emails contradictoires.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AdminCoachApplicationService {

    private final CoachProfileRepository coachProfileRepo;
    private final UserRepository userRepository;
    private final EmailService emailService;

    // ── Consultation ─────────────────────────────────────────────

    /**
     * File des candidatures. Sans statut, on renvoie tout ; avec un statut, la
     * file correspondante.
     *
     * <p>La file PENDING est triee du <b>plus ancien au plus recent</b> : c'est
     * une file d'attente, et un dossier ne doit pas pouvoir etre repousse
     * indefiniment par l'arrivee de nouveaux. Les autres vues sont triees a
     * l'inverse, parce qu'on y cherche ce qui vient de se passer.
     */
    @Transactional(readOnly = true)
    public PageResponse<AdminCoachApplicationSummary> list(CoachStatus status, int page, int size) {
        Pageable pageable = PageRequest.of(Math.max(page, 0), Math.clamp(size, 1, 100));
        Page<CoachProfile> result = (status == null)
                ? coachProfileRepo.findAllByOrderBySubmittedAtDesc(pageable)
                : coachProfileRepo.findByStatusOrderBySubmittedAtAsc(status, pageable);
        return PageResponse.of(result, this::toSummary);
    }

    /** Compteur par statut, pour les pastilles de la console. */
    @Transactional(readOnly = true)
    public Map<String, Long> countsByStatus() {
        return java.util.Arrays.stream(CoachStatus.values())
                .collect(java.util.stream.Collectors.toMap(
                        Enum::name, coachProfileRepo::countByStatus));
    }

    @Transactional(readOnly = true)
    public AdminCoachApplicationDetail detail(UUID profileId) {
        return toDetail(load(profileId));
    }

    // ── Decisions ────────────────────────────────────────────────

    /**
     * Valide le dossier : le coach entre dans l'annuaire et peut exercer.
     *
     * <p>Accepte depuis PENDING (le cas normal) et depuis SUSPENDED (une
     * suspension levee). Refuse depuis DRAFT : approuver un dossier que le
     * coach n'a pas soumis reviendrait a valider des justificatifs qu'il est
     * peut-etre encore en train de remplacer.
     */
    @Transactional
    public AdminCoachApplicationDetail approve(UUID adminId, UUID profileId) {
        CoachProfile profile = load(profileId);
        if (profile.getStatus() == CoachStatus.DRAFT) {
            throw new BusinessException(
                    "Ce dossier n'a pas encore ete soumis par le coach : rien ne peut etre valide.");
        }
        if (profile.getStatus() == CoachStatus.APPROVED) {
            throw new BusinessException("Ce coach est deja valide.");
        }

        stamp(profile, adminId, CoachStatus.APPROVED);
        profile.setRejectionReason(null);
        coachProfileRepo.save(profile);

        User coach = profile.getUser();
        emailService.sendCoachApproved(coach.getEmail(), coach.getFullName());
        log.info("Candidature coach APPROUVEE : profil {} par admin {}", profileId, adminId);

        return toDetail(profile);
    }

    /**
     * Refuse le dossier avec un motif, que le coach recoit par email et voit
     * dans l'application.
     *
     * <p>Le refus <b>ne ferme pas le compte</b> : le coach repasse en etat
     * modifiable, corrige, et resoumet. C'est le comportement voulu -- la
     * plupart des refus portent sur la qualite des photos, pas sur la sincerite
     * du dossier.
     */
    @Transactional
    public AdminCoachApplicationDetail reject(UUID adminId, UUID profileId, String reason) {
        CoachProfile profile = load(profileId);
        if (profile.getStatus() != CoachStatus.PENDING) {
            throw new BusinessException(
                    "Seul un dossier en attente d'examen peut etre refuse (etat actuel : "
                            + profile.getStatus() + ").");
        }

        stamp(profile, adminId, CoachStatus.REJECTED);
        profile.setRejectionReason(reason.trim());
        coachProfileRepo.save(profile);

        User coach = profile.getUser();
        emailService.sendCoachRejected(coach.getEmail(), coach.getFullName(), reason.trim());
        log.info("Candidature coach REFUSEE : profil {} par admin {}", profileId, adminId);

        return toDetail(profile);
    }

    /**
     * Suspend un coach <b>deja approuve</b> : signalement, litige, doute
     * apparu apres coup.
     *
     * <p>Distinct d'un refus, et pas seulement par le libelle. Un coach suspendu
     * a des adherents en suivi et des conversations ouvertes : la suspension le
     * retire de l'annuaire et lui interdit de nouvelles demandes, sans effacer
     * ce qui existe. Le retour en arriere se fait par {@link #approve}.
     */
    @Transactional
    public AdminCoachApplicationDetail suspend(UUID adminId, UUID profileId, String reason) {
        CoachProfile profile = load(profileId);
        if (profile.getStatus() != CoachStatus.APPROVED) {
            throw new BusinessException(
                    "Seul un coach valide peut etre suspendu (etat actuel : " + profile.getStatus() + ").");
        }

        stamp(profile, adminId, CoachStatus.SUSPENDED);
        profile.setRejectionReason(reason.trim());
        // Coupe aussi les nouvelles demandes de suivi, en plus du retrait de
        // l'annuaire : les deux verrous ne dependent pas du meme champ.
        profile.setAcceptingClients(false);
        coachProfileRepo.save(profile);

        log.info("Coach SUSPENDU : profil {} par admin {}", profileId, adminId);
        return toDetail(profile);
    }

    // ── Interne ──────────────────────────────────────────────────

    private CoachProfile load(UUID profileId) {
        return coachProfileRepo.findById(profileId)
                .orElseThrow(() -> new ResourceNotFoundException("Dossier de candidature introuvable"));
    }

    /** Pose l'etat, la date et l'auteur de la decision en une fois. */
    private void stamp(CoachProfile profile, UUID adminId, CoachStatus status) {
        User admin = userRepository.findById(adminId)
                .orElseThrow(() -> new ResourceNotFoundException("Administrateur introuvable"));
        profile.setStatus(status);
        profile.setReviewedAt(Instant.now());
        profile.setReviewedBy(admin);
    }

    private AdminCoachApplicationSummary toSummary(CoachProfile p) {
        User u = p.getUser();
        return new AdminCoachApplicationSummary(
                p.getId(), u.getId(), u.getFullName(), u.getEmail(), u.getAvatarUrl(),
                p.getStatus(), p.getHeadline(), p.getCity(), p.getYearsExperience(),
                p.getDocuments() == null ? 0 : p.getDocuments().size(),
                p.getSubmittedAt(), p.getReviewedAt(), u.getCreatedAt());
    }

    private AdminCoachApplicationDetail toDetail(CoachProfile p) {
        User u = p.getUser();
        return new AdminCoachApplicationDetail(
                p.getId(), u.getId(),
                u.getFullName(), u.getEmail(), u.getPhoneNumber(), u.getAvatarUrl(),
                u.getCreatedAt(), u.isEmailVerified(),
                p.getHeadline(), p.getBio(), p.getYearsExperience(), p.getHourlyRate(), p.getCity(),
                p.getSpecialties(),
                p.getCertifications().stream()
                        .map(c -> new CertificationDto(c.getId(), c.getTitle(), c.getOrganization(),
                                c.getYear(), c.getCredentialUrl()))
                        .toList(),
                p.getEducations().stream()
                        .map(e -> new EducationDto(e.getId(), e.getDegree(), e.getInstitution(),
                                e.getFieldOfStudy(), e.getYear()))
                        .toList(),
                p.getExperiences().stream()
                        .map(e -> new ExperienceDto(e.getId(), e.getTitle(), e.getOrganization(),
                                e.getStartYear(), e.getEndYear(), e.getDescription()))
                        .toList(),
                (p.getDocuments() == null ? List.<CoachDocument>of() : p.getDocuments())
                        .stream().map(CoachDocumentResponse::from).toList(),
                p.getStatus(), p.getSubmittedAt(), p.getReviewedAt(),
                p.getReviewedBy() == null ? null : p.getReviewedBy().getFullName(),
                p.getRejectionReason());
    }
}
