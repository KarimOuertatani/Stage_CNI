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
 * Experience professionnelle du coach (poste occupe dans une structure).
 * endYear null = poste toujours en cours.
 */
@Entity
@Table(name = "coach_experiences")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CoachExperienceItem {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "coach_profile_id", nullable = false)
    private CoachProfile coachProfile;

    /** Intitule du poste (ex : "Coach personnel"). */
    @Column(nullable = false)
    private String title;

    /** Structure / salle / club. */
    private String organization;

    /** Annee de debut. */
    private Integer startYear;

    /** Annee de fin (null = en cours). */
    private Integer endYear;

    /** Description des missions. */
    @Column(length = 1000)
    private String description;
}
