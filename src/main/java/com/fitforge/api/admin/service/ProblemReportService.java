package com.fitforge.api.admin.service;

import com.fitforge.api.admin.dto.AdminProblemReportResponse;
import com.fitforge.api.admin.dto.CreateProblemReportRequest;
import com.fitforge.api.admin.dto.ProblemReportResponse;
import com.fitforge.api.admin.entity.ProblemReport;
import com.fitforge.api.admin.repository.ProblemReportRepository;
import com.fitforge.api.common.dto.PageResponse;
import com.fitforge.api.common.enums.ProblemStatus;
import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Signalements de problemes : depot par l'utilisateur, traitement par
 * l'administration.
 *
 * <h2>Un seul service pour les deux cotes</h2>
 * Le partage est assume : ce sont les memes lignes, lues avec deux niveaux de
 * detail. Les scinder en deux services obligerait a dupliquer le chargement et
 * les regles de transition d'etat, avec le risque habituel -- une regle
 * corrigee d'un cote seulement.
 *
 * <p>La separation qui compte est ailleurs : elle est faite par l'URL et la
 * securite. Les methodes « utilisateur » prennent toutes un {@code reporterId}
 * et ne peuvent rien voir d'autre ; les methodes « administrateur » vivent
 * derriere {@code /api/v1/admin/**}.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ProblemReportService {

    /** Etats de cloture : ceux qui exigent une reponse ecrite a l'auteur. */
    private static final List<ProblemStatus> CLOSING =
            List.of(ProblemStatus.RESOLVED, ProblemStatus.CLOSED);

    private final ProblemReportRepository repository;
    private final UserRepository userRepository;
    private final AdminNotificationService adminNotifications;

    // ── Cote utilisateur ─────────────────────────────────────────

    @Transactional
    public ProblemReportResponse create(UUID reporterId, CreateProblemReportRequest req) {
        User reporter = userRepository.findById(reporterId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));

        ProblemReport report = ProblemReport.builder()
                .reporter(reporter)
                // Instantane du role : voir la documentation de l'entite.
                .reporterRole(reporter.getRole())
                .category(req.category())
                .subject(req.subject().trim())
                .description(req.description().trim())
                .attachmentUrl(blankToNull(req.attachmentUrl()))
                .platform(blankToNull(req.platform()))
                .appVersion(blankToNull(req.appVersion()))
                .status(ProblemStatus.NEW)
                .build();

        report = repository.save(report);
        adminNotifications.problemReported(reporter, report.getSubject(), report.getId());
        log.info("Signalement recu : {} ({})", report.getId(), report.getCategory());

        return ProblemReportResponse.from(report);
    }

    /** « Mes signalements » : uniquement ceux de l'appelant. */
    @Transactional(readOnly = true)
    public List<ProblemReportResponse> myReports(UUID reporterId) {
        return repository.findByReporterIdOrderByCreatedAtDesc(reporterId)
                .stream()
                .map(ProblemReportResponse::from)
                .toList();
    }

    // ── Cote administration ──────────────────────────────────────

    @Transactional(readOnly = true)
    public PageResponse<AdminProblemReportResponse> list(ProblemStatus status, int page, int size) {
        Pageable pageable = PageRequest.of(Math.max(page, 0), Math.clamp(size, 1, 100));
        Page<ProblemReport> result = (status == null)
                ? repository.findAllByOrderByCreatedAtDesc(pageable)
                : repository.findByStatusOrderByCreatedAtAsc(status, pageable);
        return PageResponse.of(result, AdminProblemReportResponse::from);
    }

    @Transactional(readOnly = true)
    public Map<String, Long> countsByStatus() {
        return Arrays.stream(ProblemStatus.values())
                .collect(Collectors.toMap(Enum::name, repository::countByStatus));
    }

    @Transactional(readOnly = true)
    public AdminProblemReportResponse detail(UUID reportId) {
        return AdminProblemReportResponse.from(load(reportId));
    }

    /**
     * Fait avancer un signalement.
     *
     * <p><b>Cloturer exige une reponse.</b> C'est la seule regle metier de cette
     * methode, et elle protege la promesse faite a l'utilisateur : son ecran
     * affichera « Resolu » avec, juste en dessous, l'explication. Un statut
     * RESOLVED sans texte serait pire que pas de reponse du tout -- il
     * annoncerait une correction sans dire laquelle, et fermerait le sujet.
     *
     * <p>Repasser un signalement clos en IN_PROGRESS reste possible : un
     * probleme qu'on croyait regle peut revenir, et forcer la creation d'un
     * doublon perdrait tout l'historique de l'echange.
     */
    @Transactional
    public AdminProblemReportResponse handle(
            UUID adminId, UUID reportId, ProblemStatus status, String response) {

        ProblemReport report = load(reportId);
        String trimmed = response == null ? null : response.trim();

        if (CLOSING.contains(status) && (trimmed == null || trimmed.isBlank())) {
            throw new BusinessException(
                    "Une reponse est obligatoire pour cloturer un signalement : l'auteur la verra dans l'application.");
        }

        User admin = userRepository.findById(adminId)
                .orElseThrow(() -> new ResourceNotFoundException("Administrateur introuvable"));

        report.setStatus(status);
        if (trimmed != null && !trimmed.isBlank()) {
            report.setAdminResponse(trimmed);
        }
        report.setHandledBy(admin);
        // handledAt marque la DERNIERE intervention, pas la premiere : c'est ce
        // qu'on veut savoir en regardant une file (« qui a bouge recemment »).
        report.setHandledAt(Instant.now());
        repository.save(report);

        log.info("Signalement {} -> {} par admin {}", reportId, status, adminId);
        return AdminProblemReportResponse.from(report);
    }

    // ── Interne ──────────────────────────────────────────────────

    private ProblemReport load(UUID reportId) {
        return repository.findById(reportId)
                .orElseThrow(() -> new ResourceNotFoundException("Signalement introuvable"));
    }

    private static String blankToNull(String value) {
        return (value == null || value.isBlank()) ? null : value.trim();
    }
}
