package com.fitforge.api.user.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

/**
 * Code de verification d'adresse email a 6 chiffres, envoye a l'inscription.
 *
 * <p><b>Le code n'est jamais stocke en clair.</b> Seule son empreinte BCrypt
 * ({@link #codeHash}) est conservee : une fuite de la base ne permet pas de
 * valider un compte. La verification compare l'empreinte, comme pour un mot
 * de passe.
 *
 * <p><b>Trois garde-fous</b> contre l'attaque par force brute (un code a
 * 6 chiffres ne compte qu'un million de combinaisons) :
 * <ul>
 *   <li>expiration a {@link #expiresAt} (10 minutes) ;</li>
 *   <li>compteur {@link #attempts} plafonne — au-dela, le code est brule et
 *       il faut en demander un nouveau ;</li>
 *   <li>delai minimal entre deux renvois, calcule depuis {@link #createdAt}.</li>
 * </ul>
 *
 * <p>Une seule ligne active par utilisateur : demander un nouveau code
 * remplace le precedent.
 */
@Entity
@Table(name = "email_verification_codes", indexes = {
        @Index(name = "idx_email_verif_user", columnList = "user_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EmailVerificationCode {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Compte a verifier. Une seule ligne active par compte. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    /** Empreinte BCrypt du code a 6 chiffres — jamais le code lui-meme. */
    @Column(name = "code_hash", nullable = false)
    private String codeHash;

    /** Date d'expiration (creation + 10 minutes). */
    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    /** Nombre de tentatives infructueuses sur ce code. */
    @Column(nullable = false)
    @Builder.Default
    private int attempts = 0;

    /**
     * Date d'emission de CE code — base du delai anti-renvoi (60 s).
     *
     * <p>Volontairement <b>sans</b> {@code @CreationTimestamp} ni
     * {@code updatable = false} : demander un nouveau code reecrit la meme
     * ligne, et cet horodatage doit alors repartir de zero. Avec
     * {@code updatable = false}, Hibernate l'aurait exclu de l'UPDATE et le
     * delai anti-renvoi serait reste calcule depuis le tout premier code —
     * donc inoperant des la 61e seconde.
     */
    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    /** Vrai si le code a depasse sa date de validite. */
    public boolean isExpired() {
        return Instant.now().isAfter(expiresAt);
    }
}
