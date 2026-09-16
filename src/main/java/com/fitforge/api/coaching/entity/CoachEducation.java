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
 * Formation / etude suivie par le coach (ex : "Licence STAPS", 2018).
 */
@Entity
@Table(name = "coach_educations")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CoachEducation {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "coach_profile_id", nullable = false)
    private CoachProfile coachProfile;

    /** Diplome obtenu (ex : "Licence STAPS"). */
    @Column(nullable = false)
    private String degree;

    /** Etablissement. */
    private String institution;

    /** Domaine d'etude (ex : "Entrainement sportif"). */
    private String fieldOfStudy;

    /** Annee d'obtention. */
    private Integer year;
}
