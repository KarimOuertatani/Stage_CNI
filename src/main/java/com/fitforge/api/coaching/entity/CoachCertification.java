package com.fitforge.api.coaching.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.UUID;

/**
 * Certification / diplome professionnel du coach (ex : "NSCA-CPT", 2019).
 */
@Entity
@Table(name = "coach_certifications")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CoachCertification {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "coach_profile_id", nullable = false)
    private CoachProfile coachProfile;

    /** Intitule de la certification (ex : "Coach sportif BPJEPS"). */
    @Column(nullable = false)
    private String title;

    /** Organisme delivrant la certification. */
    private String organization;

    /** Annee d'obtention. */
    private Integer year;

    /** Lien de verification (optionnel). */
    private String credentialUrl;
}
