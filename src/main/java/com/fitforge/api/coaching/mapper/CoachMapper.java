package com.fitforge.api.coaching.mapper;

import com.fitforge.api.coaching.dto.CertificationDto;
import com.fitforge.api.coaching.dto.ChatMessageResponse;
import com.fitforge.api.coaching.dto.CoachProfileResponse;
import com.fitforge.api.coaching.dto.CoachSummaryResponse;
import com.fitforge.api.coaching.dto.EducationDto;
import com.fitforge.api.coaching.dto.ExperienceDto;
import com.fitforge.api.coaching.dto.PersonRef;
import com.fitforge.api.coaching.entity.ChatMessage;
import com.fitforge.api.coaching.entity.CoachCertification;
import com.fitforge.api.coaching.entity.CoachEducation;
import com.fitforge.api.coaching.entity.CoachExperienceItem;
import com.fitforge.api.coaching.entity.CoachProfile;
import com.fitforge.api.common.enums.CoachingStatus;
import com.fitforge.api.user.entity.User;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.UUID;

/**
 * Conversions entites <-> DTO du domaine coaching. Ecrit a la main (plutot que
 * MapStruct) car plusieurs champs sont calcules (statut de relation du
 * demandeur, apercu de conversation, non-lus).
 */
@Component
public class CoachMapper {

    // ── Coach ────────────────────────────────────────────────────

    public CoachSummaryResponse toSummary(CoachProfile p) {
        User u = p.getUser();
        return new CoachSummaryResponse(
                u.getId(),
                p.getId(),
                u.getFullName(),
                u.getAvatarUrl(),
                p.getHeadline(),
                p.getCity(),
                p.getYearsExperience(),
                p.getSpecialties(),
                p.getRatingAverage(),
                p.getRatingCount(),
                p.isAcceptingClients()
        );
    }

    public CoachProfileResponse toProfile(CoachProfile p,
                                          CoachingStatus viewerStatus,
                                          UUID viewerRelationshipId) {
        User u = p.getUser();
        return new CoachProfileResponse(
                u.getId(),
                p.getId(),
                u.getFullName(),
                u.getAvatarUrl(),
                p.getHeadline(),
                p.getBio(),
                p.getYearsExperience(),
                p.getHourlyRate(),
                p.getCity(),
                p.getStatus(),
                p.isAcceptingClients(),
                p.getRatingAverage(),
                p.getRatingCount(),
                p.getSpecialties(),
                p.getCertifications().stream().map(this::toDto).toList(),
                p.getEducations().stream().map(this::toDto).toList(),
                p.getExperiences().stream().map(this::toDto).toList(),
                viewerStatus,
                viewerRelationshipId
        );
    }

    public CertificationDto toDto(CoachCertification c) {
        return new CertificationDto(c.getId(), c.getTitle(), c.getOrganization(),
                c.getYear(), c.getCredentialUrl());
    }

    public EducationDto toDto(CoachEducation e) {
        return new EducationDto(e.getId(), e.getDegree(), e.getInstitution(),
                e.getFieldOfStudy(), e.getYear());
    }

    public ExperienceDto toDto(CoachExperienceItem e) {
        return new ExperienceDto(e.getId(), e.getTitle(), e.getOrganization(),
                e.getStartYear(), e.getEndYear(), e.getDescription());
    }

    // ── Personnes ────────────────────────────────────────────────

    public PersonRef toPersonRef(User u, String headline) {
        return new PersonRef(u.getId(), u.getFullName(), u.getAvatarUrl(), headline);
    }

    // ── Chat ─────────────────────────────────────────────────────

    public ChatMessageResponse toMessage(ChatMessage m) {
        User s = m.getSender();
        return new ChatMessageResponse(
                m.getId(),
                m.getRelationship().getId(),
                s.getId(),
                s.getFullName(),
                m.getContent(),
                m.getAttachmentUrl(),
                m.getAttachmentKind(),
                m.getAttachmentName(),
                m.getAttachmentSize(),
                m.getAttachmentDurationSec(),
                m.getSentAt(),
                m.getReadAt()
        );
    }

    /**
     * Apercu texte d'un message pour les listes de conversations : le texte s'il
     * existe, sinon un libelle base sur la piece jointe.
     */
    public String previewOf(ChatMessage m) {
        if (m == null) return null;
        if (m.getContent() != null && !m.getContent().isBlank()) return m.getContent();
        if (m.getAttachmentKind() == null) return null;
        return switch (m.getAttachmentKind()) {
            case IMAGE -> "📷 Photo";
            case AUDIO -> "🎙️ Message vocal";
            case FILE -> "📎 " + (m.getAttachmentName() != null ? m.getAttachmentName() : "Pièce jointe");
        };
    }

    // ── Construction des sous-entites depuis les DTO (upsert profil) ──

    public CoachCertification toEntity(CertificationDto d, CoachProfile parent) {
        return CoachCertification.builder()
                .coachProfile(parent)
                .title(d.title())
                .organization(d.organization())
                .year(d.year())
                .credentialUrl(d.credentialUrl())
                .build();
    }

    public CoachEducation toEntity(EducationDto d, CoachProfile parent) {
        return CoachEducation.builder()
                .coachProfile(parent)
                .degree(d.degree())
                .institution(d.institution())
                .fieldOfStudy(d.fieldOfStudy())
                .year(d.year())
                .build();
    }

    public CoachExperienceItem toEntity(ExperienceDto d, CoachProfile parent) {
        return CoachExperienceItem.builder()
                .coachProfile(parent)
                .title(d.title())
                .organization(d.organization())
                .startYear(d.startYear())
                .endYear(d.endYear())
                .description(d.description())
                .build();
    }

    public List<CoachCertification> certs(List<CertificationDto> in, CoachProfile parent) {
        return in == null ? List.of() : in.stream().map(d -> toEntity(d, parent)).toList();
    }

    public List<CoachEducation> educations(List<EducationDto> in, CoachProfile parent) {
        return in == null ? List.of() : in.stream().map(d -> toEntity(d, parent)).toList();
    }

    public List<CoachExperienceItem> experiences(List<ExperienceDto> in, CoachProfile parent) {
        return in == null ? List.of() : in.stream().map(d -> toEntity(d, parent)).toList();
    }
}
