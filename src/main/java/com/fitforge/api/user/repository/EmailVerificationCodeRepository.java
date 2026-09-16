package com.fitforge.api.user.repository;

import com.fitforge.api.user.entity.EmailVerificationCode;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

/**
 * Acces aux codes de verification d'email.
 *
 * <p>Une seule ligne active par compte : la contrainte d'unicite sur
 * {@code user_id} garantit qu'un nouveau code remplace toujours le precedent.
 */
public interface EmailVerificationCodeRepository
        extends JpaRepository<EmailVerificationCode, UUID> {

    /** Code en cours pour un compte donne. */
    Optional<EmailVerificationCode> findByUserId(UUID userId);

    /** Supprime le code d'un compte (verification reussie, ou renvoi). */
    void deleteByUserId(UUID userId);
}
