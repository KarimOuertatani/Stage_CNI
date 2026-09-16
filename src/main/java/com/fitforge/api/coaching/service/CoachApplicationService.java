package com.fitforge.api.coaching.service;

import com.fitforge.api.admin.service.AdminNotificationService;
import com.fitforge.api.coaching.dto.CoachApplicationResponse;
import com.fitforge.api.coaching.dto.CoachDocumentResponse;
import com.fitforge.api.coaching.entity.CoachDocument;
import com.fitforge.api.coaching.entity.CoachProfile;
import com.fitforge.api.coaching.repository.CoachDocumentRepository;
import com.fitforge.api.coaching.repository.CoachProfileRepository;
import com.fitforge.api.common.enums.CoachDocumentType;
import com.fitforge.api.common.enums.CoachStatus;
import com.fitforge.api.common.enums.Role;
import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.media.PrivateStorageService;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.Resource;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Constitution et soumission du dossier de candidature d'un coach.
 *
 * <h2>Ce que ce service protege</h2>
 * L'inscription coach ne suffit plus a exercer. Entre la creation du compte et
 * l'apparition dans l'annuaire, il y a desormais un dossier a constituer, une
 * soumission explicite, et un examen humain. Ce service tient les deux
 * premieres etapes -- l'examen appartient a
 * {@code AdminCoachApplicationService}.
 *
 * <h2>La regle de completude vit ICI, et nulle part ailleurs</h2>
 * {@link #missingRequirements(CoachProfile)} est la seule definition de ce
 * qu'est un dossier complet. Elle sert a la fois a <b>afficher</b> ce qu'il
 * reste a faire et a <b>refuser</b> une soumission incomplete. Dupliquer la
 * regle cote application produirait tot ou tard l'ecran le plus decourageant
 * qui soit : un bouton actif qui echoue sans expliquer pourquoi.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CoachApplicationService {

    /**
     * Etats dans lesquels le coach peut encore modifier son dossier.
     *
     * <p>DRAFT est evident. REJECTED l'est tout autant : un refus qui
     * n'autoriserait aucune correction n'aurait pas besoin de motif. En
     * revanche, un dossier PENDING est <b>gele</b> -- voir
     * {@link #assertEditable(CoachProfile)}.
     */
    private static final Set<CoachStatus> EDITABLE = EnumSet.of(CoachStatus.DRAFT, CoachStatus.REJECTED);

    /** Longueur minimale d'une biographie pour qu'elle apporte quelque chose. */
    private static final int MIN_BIO_LENGTH = 80;

    private final CoachProfileRepository coachProfileRepo;
    private final CoachDocumentRepository documentRepo;
    private final UserRepository userRepository;
    private final PrivateStorageService privateStorage;
    private final AdminNotificationService adminNotifications;

    // ── Consultation ─────────────────────────────────────────────

    @Transactional(readOnly = true)
    public CoachApplicationResponse getMyApplication(UUID coachUserId) {
        return toResponse(loadOwnProfile(coachUserId));
    }

    // ── Justificatifs ────────────────────────────────────────────

    /** Depose un justificatif. Le fichier va dans le stockage PRIVE. */
    @Transactional
    public CoachApplicationResponse uploadDocument(
            UUID coachUserId, CoachDocumentType type, String label, MultipartFile file) {

        CoachProfile profile = loadOwnProfile(coachUserId);
        assertEditable(profile);

        // Une piece d'identite en double n'a aucun sens et brouille l'examen :
        // l'administrateur ne saurait pas laquelle fait foi. On remplace.
        if (type == CoachDocumentType.IDENTITY) {
            profile.getDocuments().stream()
                    .filter(d -> d.getType() == CoachDocumentType.IDENTITY)
                    .toList()
                    .forEach(existing -> {
                        privateStorage.delete(existing.getStorageKey());
                        profile.getDocuments().remove(existing);
                    });
        }

        String storageKey = privateStorage.store(file);
        CoachDocument document = CoachDocument.builder()
                .coachProfile(profile)
                .type(type)
                .label(label == null || label.isBlank() ? null : label.trim())
                .storageKey(storageKey)
                .originalName(file.getOriginalFilename())
                .contentType(file.getContentType())
                .sizeBytes(file.getSize())
                .build();
        profile.getDocuments().add(document);
        coachProfileRepo.save(profile);

        return toResponse(profile);
    }

    /**
     * Retire un justificatif du dossier.
     *
     * <p>Le fichier est supprime du disque <b>apres</b> la ligne en base. Dans
     * l'ordre inverse, un echec de transaction laisserait une ligne pointant
     * vers un fichier disparu -- l'administrateur ouvrirait un document
     * fantome. L'inverse (un fichier orphelin sur le disque) ne casse rien.
     */
    @Transactional
    public CoachApplicationResponse deleteDocument(UUID coachUserId, UUID documentId) {
        CoachProfile profile = loadOwnProfile(coachUserId);
        assertEditable(profile);

        CoachDocument document = profile.getDocuments().stream()
                .filter(d -> d.getId().equals(documentId))
                .findFirst()
                .orElseThrow(() -> new ResourceNotFoundException("Justificatif introuvable"));

        String storageKey = document.getStorageKey();
        profile.getDocuments().remove(document);
        coachProfileRepo.save(profile);
        privateStorage.delete(storageKey);

        return toResponse(profile);
    }

    /**
     * Ouvre le fichier d'un justificatif, apres controle des droits.
     *
     * <p>Deux appelants legitimes, et deux seulement : <b>l'administrateur</b>,
     * qui doit examiner la piece, et <b>le coach proprietaire</b>, qui doit
     * pouvoir relire ce qu'il a envoye avant de soumettre. Tout autre compte
     * recoit un refus -- y compris un autre coach, y compris un adherent en
     * suivi avec lui.
     */
    @Transactional(readOnly = true)
    public DocumentFile loadDocumentFile(UUID requesterId, UUID documentId) {
        CoachDocument document = documentRepo.findById(documentId)
                .orElseThrow(() -> new ResourceNotFoundException("Justificatif introuvable"));

        User requester = userRepository.findById(requesterId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));

        boolean isAdmin = requester.getRole() == Role.ADMIN;
        boolean isOwner = document.getCoachProfile().getUser().getId().equals(requesterId);
        if (!isAdmin && !isOwner) {
            throw new AccessDeniedException("Acces refuse a ce justificatif");
        }

        Resource resource = privateStorage.load(document.getStorageKey());
        return new DocumentFile(
                resource,
                document.getContentType() == null ? "application/octet-stream" : document.getContentType(),
                document.getOriginalName() == null ? "justificatif" : document.getOriginalName());
    }

    /** Fichier resolu, pret a etre renvoye par le controleur. */
    public record DocumentFile(Resource resource, String contentType, String fileName) {}

    // ── Soumission ───────────────────────────────────────────────

    /**
     * Soumet le dossier a l'examen de l'administration.
     *
     * <p>Le passage en PENDING <b>gele</b> le dossier : sans cela, un coach
     * pourrait remplacer ses justificatifs pendant que l'administrateur les
     * consulte, et la decision porterait sur des pieces qui ne sont plus la.
     *
     * <p>Le motif de refus precedent est efface a la resoumission. Le garder
     * afficherait, sur un dossier en attente, la raison d'un refus deja
     * corrige.
     */
    @Transactional
    public CoachApplicationResponse submit(UUID coachUserId) {
        CoachProfile profile = loadOwnProfile(coachUserId);

        if (profile.getStatus() == CoachStatus.PENDING) {
            throw new BusinessException("Ton dossier est deja en cours d'examen");
        }
        if (profile.getStatus() == CoachStatus.APPROVED) {
            throw new BusinessException("Ton profil est deja valide");
        }
        if (profile.getStatus() == CoachStatus.SUSPENDED) {
            throw new BusinessException(
                    "Ton compte est suspendu. Contacte l'equipe FitForge pour le reactiver.");
        }

        List<String> missing = missingRequirements(profile);
        if (!missing.isEmpty()) {
            throw new BusinessException("Ton dossier est incomplet : " + String.join(" ", missing));
        }

        profile.setStatus(CoachStatus.PENDING);
        profile.setSubmittedAt(Instant.now());
        profile.setRejectionReason(null);
        profile.setReviewedAt(null);
        profile.setReviewedBy(null);
        coachProfileRepo.save(profile);

        adminNotifications.coachApplicationSubmitted(profile);
        log.info("Dossier coach soumis pour examen : profil {}", profile.getId());

        return toResponse(profile);
    }

    // ── Regle de completude ──────────────────────────────────────

    /**
     * Ce qu'il manque au dossier, en phrases directement affichables.
     *
     * <p>Les messages sont ecrits a la deuxieme personne et a l'imperatif
     * (« Ajoute... »), parce qu'ils s'affichent dans une liste de choses a
     * faire, pas dans un rapport d'erreur. « Le champ bio est requis » decrit
     * un formulaire ; « Ecris une presentation d'au moins 80 caracteres » dit
     * quoi faire.
     */
    List<String> missingRequirements(CoachProfile profile) {
        List<String> missing = new ArrayList<>();

        if (isBlank(profile.getHeadline())) {
            missing.add("Ajoute une accroche qui resume ta specialite.");
        }
        if (profile.getBio() == null || profile.getBio().trim().length() < MIN_BIO_LENGTH) {
            missing.add("Ecris une presentation d'au moins " + MIN_BIO_LENGTH + " caracteres.");
        }
        if (profile.getSpecialties() == null || profile.getSpecialties().isEmpty()) {
            missing.add("Choisis au moins une specialite.");
        }
        if (profile.getYearsExperience() == null || profile.getYearsExperience() < 0) {
            missing.add("Indique ton nombre d'annees d'experience.");
        }

        // Les titres revendiques (texte) et les justificatifs (fichiers) sont
        // deux exigences distinctes : une photo de diplome sans intitule ne dit
        // pas ce que le coach pretend avoir, et un intitule sans photo n'est
        // qu'une affirmation. L'examen a besoin des deux, en vis-a-vis.
        boolean claimsQualification =
                (profile.getCertifications() != null && !profile.getCertifications().isEmpty())
                        || (profile.getEducations() != null && !profile.getEducations().isEmpty());
        if (!claimsQualification) {
            missing.add("Renseigne au moins une certification ou un diplome.");
        }

        List<CoachDocument> documents = profile.getDocuments() == null ? List.of() : profile.getDocuments();
        boolean hasIdentity = documents.stream().anyMatch(d -> d.getType() == CoachDocumentType.IDENTITY);
        boolean hasProof = documents.stream().anyMatch(
                d -> d.getType() == CoachDocumentType.DIPLOMA || d.getType() == CoachDocumentType.CERTIFICATION);

        if (!hasIdentity) {
            missing.add("Ajoute une photo de ta piece d'identite.");
        }
        if (!hasProof) {
            missing.add("Ajoute la photo d'au moins un diplome ou certificat.");
        }
        return missing;
    }

    // ── Interne ──────────────────────────────────────────────────

    private CoachProfile loadOwnProfile(UUID coachUserId) {
        return coachProfileRepo.findByUserId(coachUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Profil coach introuvable"));
    }

    /**
     * Refuse toute modification d'un dossier qui n'est pas modifiable, avec un
     * message qui explique l'etat plutot que de dire « interdit ».
     */
    private void assertEditable(CoachProfile profile) {
        if (EDITABLE.contains(profile.getStatus())) {
            return;
        }
        String message = switch (profile.getStatus()) {
            case PENDING -> "Ton dossier est en cours d'examen : il ne peut plus etre modifie.";
            case APPROVED -> "Ton profil est deja valide.";
            case SUSPENDED -> "Ton compte est suspendu. Contacte l'equipe FitForge.";
            default -> "Ce dossier ne peut pas etre modifie.";
        };
        throw new BusinessException(message);
    }

    private CoachApplicationResponse toResponse(CoachProfile profile) {
        List<String> missing = missingRequirements(profile);
        List<CoachDocumentResponse> documents = (profile.getDocuments() == null ? List.<CoachDocument>of()
                : profile.getDocuments())
                .stream()
                .map(CoachDocumentResponse::from)
                .toList();

        // canSubmit combine la completude ET l'etat : un dossier complet mais
        // deja en attente d'examen ne doit pas afficher un bouton actif.
        boolean canSubmit = missing.isEmpty() && EDITABLE.contains(profile.getStatus());

        return new CoachApplicationResponse(
                profile.getStatus(),
                profile.getSubmittedAt(),
                profile.getReviewedAt(),
                profile.getRejectionReason(),
                documents,
                missing,
                canSubmit);
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
