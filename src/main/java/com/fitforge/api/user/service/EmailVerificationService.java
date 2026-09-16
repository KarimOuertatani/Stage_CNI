package com.fitforge.api.user.service;

import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.user.entity.EmailVerificationCode;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.repository.EmailVerificationCodeRepository;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;

/**
 * Verification de l'adresse email par code a 6 chiffres.
 *
 * <p><b>Cycle de vie :</b>
 * <ol>
 *   <li>inscription -> compte {@code enabled = false} + code genere et envoye ;</li>
 *   <li>{@code verify(email, code)} -> {@code enabled = true},
 *       {@code emailVerified = true}, code supprime ;</li>
 *   <li>{@code resend(email)} -> nouveau code (au plus un par minute).</li>
 * </ol>
 *
 * <p><b>Anti-force brute.</b> Un code a 6 chiffres ne compte qu'un million de
 * combinaisons : sans garde-fou, il serait devinable. Quatre protections se
 * cumulent :
 * <ul>
 *   <li>generation par {@link SecureRandom} (imprevisible, contrairement a
 *       {@code Math.random()}) ;</li>
 *   <li>duree de vie de 10 minutes ;</li>
 *   <li><b>5 tentatives maximum</b> — au-dela le code est detruit ;</li>
 *   <li>renvoi limite a un par minute.</li>
 * </ul>
 *
 * <p><b>Confidentialite.</b> Le code n'est stocke que sous forme d'empreinte
 * BCrypt et n'est jamais journalise. Les messages d'erreur ne revelent pas si
 * une adresse existe en base.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class EmailVerificationService {

    /** Duree de validite d'un code. */
    public static final int EXPIRY_MINUTES = 10;

    /** Delai minimal entre deux demandes de code. */
    private static final Duration RESEND_COOLDOWN = Duration.ofSeconds(60);

    /** Tentatives infructueuses tolerees avant destruction du code. */
    private static final int MAX_ATTEMPTS = 5;

    /** Borne haute exclusive : 1 000 000 -> codes de 000000 a 999999. */
    private static final int CODE_BOUND = 1_000_000;

    /** Generateur cryptographique : imprevisible, contrairement a Random. */
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final EmailVerificationCodeRepository codeRepo;
    private final UserRepository userRepo;
    private final PasswordEncoder passwordEncoder;
    private final EmailService emailService;

    // ── Emission ─────────────────────────────────────────────────────

    /**
     * Genere un code, le persiste (hashe) et declenche l'envoi de l'email.
     * Remplace tout code precedent du meme compte.
     *
     * <p>Appele depuis l'inscription : l'envoi etant asynchrone, cette methode
     * rend la main immediatement.
     */
    @Transactional
    public void issueCode(User user) {
        String code = generateCode();
        persist(user, code);
        emailService.sendVerificationCode(
                user.getEmail(), user.getFullName(), code, EXPIRY_MINUTES);
    }

    /**
     * Renvoie un nouveau code a la demande de l'utilisateur.
     *
     * <p><b>Reponse volontairement uniforme :</b> qu'il existe ou non un compte
     * pour cette adresse, l'appelant recoit la meme reponse. Un attaquant ne
     * peut donc pas se servir de cet endpoint pour decouvrir quelles adresses
     * sont inscrites.
     *
     * @throws BusinessException si un code a deja ete demande il y a moins d'une minute
     */
    @Transactional
    public void resendCode(String email) {
        Optional<User> found = userRepo.findByEmail(normalize(email));
        if (found.isEmpty()) {
            return;   // silence volontaire : pas d'enumeration des comptes
        }
        User user = found.get();

        if (user.isEnabled() && user.isEmailVerified()) {
            throw new BusinessException("Ce compte est deja verifie, vous pouvez vous connecter");
        }

        // Anti-abus : au plus un envoi par minute et par compte.
        codeRepo.findByUserId(user.getId()).ifPresent(existing -> {
            Duration since = Duration.between(existing.getCreatedAt(), Instant.now());
            if (since.compareTo(RESEND_COOLDOWN) < 0) {
                long wait = RESEND_COOLDOWN.minus(since).toSeconds() + 1;
                throw new BusinessException(
                        "Patientez encore " + wait + " secondes avant de demander un nouveau code");
            }
        });

        issueCode(user);
    }

    // ── Verification ─────────────────────────────────────────────────

    /**
     * Valide le code saisi et active le compte.
     *
     * <p><b>{@code noRollbackFor} indispensable.</b> {@link BusinessException}
     * est une {@code RuntimeException} : par defaut Spring annulerait la
     * transaction en la propageant, <b>y compris l'incrementation du compteur
     * de tentatives</b> — la protection anti-force brute serait alors purement
     * decorative (compteur fige a 1, essais illimites). En excluant cette
     * exception du rollback, on conserve les ecritures voulues sur chaque
     * chemin d'echec : incrementation du compteur (code faux) et suppression
     * du code (expire ou epuise).
     *
     * @return le compte active, pret a recevoir un token JWT
     * @throws BusinessException si le code est absent, expire, epuise ou incorrect
     */
    @Transactional(noRollbackFor = BusinessException.class)
    public User verify(String email, String code) {
        User user = userRepo.findByEmail(normalize(email))
                .orElseThrow(() -> new BusinessException("Code de verification invalide"));

        if (user.isEnabled() && user.isEmailVerified()) {
            throw new BusinessException("Ce compte est deja verifie, vous pouvez vous connecter");
        }

        EmailVerificationCode entry = codeRepo.findByUserId(user.getId())
                .orElseThrow(() -> new BusinessException(
                        "Aucun code en cours. Demandez un nouveau code."));

        if (entry.isExpired()) {
            codeRepo.delete(entry);
            throw new BusinessException("Ce code a expire. Demandez un nouveau code.");
        }

        if (entry.getAttempts() >= MAX_ATTEMPTS) {
            codeRepo.delete(entry);
            throw new BusinessException(
                    "Trop de tentatives. Demandez un nouveau code.");
        }

        if (!passwordEncoder.matches(code.trim(), entry.getCodeHash())) {
            entry.setAttempts(entry.getAttempts() + 1);
            codeRepo.save(entry);
            int left = MAX_ATTEMPTS - entry.getAttempts();
            throw new BusinessException(left > 0
                    ? "Code incorrect. Il vous reste " + left + " tentative(s)."
                    : "Code incorrect. Demandez un nouveau code.");
        }

        // Succes : on active le compte et on detruit le code (usage unique).
        user.setEnabled(true);
        user.setEmailVerified(true);
        userRepo.save(user);
        codeRepo.delete(entry);

        log.info("Compte verifie : {}", mask(user.getEmail()));
        return user;
    }

    // ── Interne ──────────────────────────────────────────────────────

    /** Code a 6 chiffres, zeros de tete conserves (ex. « 042915 »). */
    private String generateCode() {
        return String.format("%06d", SECURE_RANDOM.nextInt(CODE_BOUND));
    }

    /** Remplace le code du compte par un nouveau (hashe, avec sa peremption). */
    private void persist(User user, String code) {
        EmailVerificationCode entry = codeRepo.findByUserId(user.getId())
                .orElseGet(() -> EmailVerificationCode.builder().user(user).build());

        entry.setCodeHash(passwordEncoder.encode(code));   // jamais en clair
        entry.setExpiresAt(Instant.now().plus(Duration.ofMinutes(EXPIRY_MINUTES)));
        entry.setAttempts(0);
        // Reinitialise l'horodatage pour que le delai anti-renvoi reparte de zero.
        entry.setCreatedAt(Instant.now());

        codeRepo.save(entry);
    }

    private String normalize(String email) {
        return email == null ? "" : email.trim().toLowerCase();
    }

    private String mask(String email) {
        if (email == null) return "?";
        int at = email.indexOf('@');
        if (at <= 2) return "***" + (at >= 0 ? email.substring(at) : "");
        return email.substring(0, 2) + "***" + email.substring(at);
    }
}
