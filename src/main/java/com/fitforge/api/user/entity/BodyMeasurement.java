package com.fitforge.api.user.entity;

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

import java.time.LocalDate;
import java.util.UUID;

/**
 * Une pesee / mensuration a une date donnee = HISTORIQUE.
 * Relation N-1 vers User : chaque nouvelle mesure est une ligne, on n'ecrase
 * jamais. Cela permet de tracer une courbe de poids dans Flutter.
 */
@Entity
@Table(name = "body_measurements")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BodyMeasurement {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Adherent proprietaire de la mesure (LAZY). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /** Date de la pesee. */
    @Column(nullable = false)
    private LocalDate measuredOn;

    private Double weightKg;
    private Double bodyFatPercent;
    private Double waistCm;    // tour de taille
    private Double chestCm;    // tour de poitrine
    private Double armCm;      // tour de bras
    private Double thighCm;    // tour de cuisse
}
