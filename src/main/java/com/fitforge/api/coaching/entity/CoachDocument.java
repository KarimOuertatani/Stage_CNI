package com.fitforge.api.coaching.entity;

import com.fitforge.api.common.enums.CoachDocumentType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
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
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

/**
 * Un justificatif depose par un coach : piece d'identite, photo de diplome ou
 * de certificat.
 *
 * <h2>Le champ le plus important est ce qu'il ne contient PAS</h2>
 * {@code storageKey} n'est <b>pas</b> une URL. Les autres medias du projet
 * (avatars, pieces jointes du chat) stockent un chemin {@code /media/<nom>}
 * directement joignable, parce qu'ils sont publics par nature. Ici le champ ne
 * porte que le nom du fichier dans un dossier prive que rien ne sert
 * statiquement -- voir {@code PrivateStorageService}.
 *
 * <p>La consequence est volontaire : <b>aucune reponse d'API ne peut fuiter une
 * URL exploitable</b>. Meme si la cle de stockage apparaissait dans un DTO, elle
 * ne designerait aucune ressource HTTP. Le seul chemin de lecture est
 * {@code GET /coach-application/documents/{id}/file}, qui verifie a chaque appel
 * que l'appelant est l'administrateur ou le coach proprietaire.
 */
@Entity
@Table(name = "coach_documents")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CoachDocument {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "coach_profile_id", nullable = false)
    private CoachProfile coachProfile;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private CoachDocumentType type;

    /**
     * Intitule saisi par le coach (« BPJEPS AGFF 2019 », « Master STAPS »).
     * Facultatif mais precieux a l'examen : il dit ce que le coach PRETEND que
     * la photo montre, ce qui est exactement l'information a confronter.
     */
    private String label;

    /** Nom du fichier dans le dossier prive. Jamais une URL. */
    @Column(name = "storage_key", nullable = false)
    private String storageKey;

    /** Nom d'origine, reaffiche a l'administrateur tel que le coach l'a envoye. */
    @Column(name = "original_name")
    private String originalName;

    @Column(name = "content_type")
    private String contentType;

    @Column(name = "size_bytes")
    private Long sizeBytes;

    @CreationTimestamp
    @Column(name = "uploaded_at", nullable = false, updatable = false)
    private Instant uploadedAt;
}
