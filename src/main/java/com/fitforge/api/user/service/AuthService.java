package com.fitforge.api.user.service;

import com.fitforge.api.common.enums.MediaKind;
import com.fitforge.api.admin.service.AdminNotificationService;
import com.fitforge.api.common.enums.Role;
import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.media.StorageService;
import com.fitforge.api.security.JwtService;
import com.fitforge.api.user.dto.AccountResponse;
import com.fitforge.api.user.dto.AuthResponse;
import com.fitforge.api.user.dto.LoginRequest;
import com.fitforge.api.user.dto.RegisterRequest;
import com.fitforge.api.user.dto.RegistrationResponse;
import com.fitforge.api.user.dto.VerifyEmailRequest;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.entity.UserProfile;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.Instant;
import java.time.LocalDate;
import java.time.Period;
import java.util.UUID;

/**
 * Logique metier de l'authentification : inscription, connexion (JWT), /me.
 * Aucune logique de securite n'est laissee au controller.
 */
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;
    private final StorageService storage;
    private final EmailVerificationService verificationService;
    private final AdminNotificationService adminNotifications;

    /** Normalise l'email : la casse ne doit jamais empecher une connexion. */
    private String normalize(String email) {
        return email == null ? "" : email.trim().toLowerCase();
    }

    /**
     * Cree un compte adherent <b>desactive</b> et envoie un code de
     * verification par email.
     *
     * <p>Regles metier : email unique, mot de passe stocke hashe (BCrypt), et
     * surtout {@code enabled = false} — le compte ne peut pas se connecter tant
     * que l'adresse n'est pas confirmee. Aucun token n'est renvoye ici : c'est
     * {@link #verifyEmail} qui le delivre, une fois le code valide.
     */
    @Transactional
    public RegistrationResponse register(RegisterRequest req) {
        String email = normalize(req.email());
        if (userRepository.existsByEmail(email)) {
            throw new BusinessException("Un compte existe deja avec cet email");
        }

        User user = User.builder()
                .email(email)
                .passwordHash(passwordEncoder.encode(req.password()))  // jamais en clair
                .fullName(req.fullName())
                .phoneNumber(req.phoneNumber())
                .role(Role.ADHERENT)          // partie 1 : tout le monde est adherent
                .enabled(false)               // active seulement apres verification
                .emailVerified(false)
                .build();

        // On cree deja le profil avec la date de naissance saisie a l'inscription,
        // et on calcule l'age. Le poids/taille (donc IMC/TDEE) viendront plus tard
        // via PUT /profile, d'ou onboardingCompleted = false pour l'instant.
        UserProfile profile = new UserProfile();
        profile.setUser(user);
        profile.setBirthDate(req.birthDate());
        profile.setAge(Period.between(req.birthDate(), LocalDate.now()).getYears());
        profile.setOnboardingCompleted(false);
        // Relation 1-1 : cascade ALL depuis User -> le profil est insere avec le compte
        user.setProfile(profile);

        user = userRepository.save(user);

        // Genere le code et declenche l'envoi (asynchrone : pas d'attente ici).
        verificationService.issueCode(user);

        return new RegistrationResponse(
                user.getEmail(),
                EmailVerificationService.EXPIRY_MINUTES,
                "Un code de verification a ete envoye a " + user.getEmail());
    }

    /**
     * Valide le code recu par email, active le compte et renvoie le token :
     * c'est ce qui remplace l'ancienne auto-connexion a l'inscription.
     *
     * <p><b>{@code noRollbackFor} obligatoire ici aussi.</b> Cette methode et
     * {@link EmailVerificationService#verify} partagent la MEME transaction
     * (propagation REQUIRED). Sans cette exclusion, l'intercepteur de ce
     * niveau marquerait la transaction pour annulation en voyant remonter la
     * {@link BusinessException}, et effacerait l'incrementation du compteur de
     * tentatives faite par le service interne — rendant sa protection
     * anti-force brute inoperante.
     */
    @Transactional(noRollbackFor = BusinessException.class)
    public AuthResponse verifyEmail(VerifyEmailRequest req) {
        User user = verificationService.verify(req.email(), req.code());
        user.setLastLoginAt(Instant.now());
        userRepository.save(user);

        // Notification a l'administration -- ICI, et non dans register().
        //
        // Une inscription non confirmee ne produit rien d'observable : le compte
        // ne peut pas se connecter, il n'existe pour personne. Notifier a la
        // creation remplirait la cloche de comptes fantomes (adresse mal
        // saisie, inscription abandonnee), au point de noyer les evenements qui
        // demandent vraiment une action. Le moment ou un adherent « arrive »
        // est celui ou son compte devient utilisable.
        //
        // Les coachs sont exclus : leur arrivee interessante n'est pas leur
        // inscription mais la soumission de leur dossier, deja notifiee par
        // CoachApplicationService.submit. Deux notifications pour le meme coach
        // feraient croire a deux evenements distincts.
        if (user.getRole() == Role.ADHERENT) {
            adminNotifications.memberRegistered(user);
        }

        return buildAuthResponse(user);
    }

    /** Renvoie un nouveau code (au plus un par minute, cf. service dedie). */
    @Transactional
    public void resendVerificationCode(String email) {
        verificationService.resendCode(email);
    }

    /**
     * Verifie les identifiants via l'AuthenticationManager (qui utilise BCrypt),
     * met a jour lastLoginAt, puis renvoie un token.
     *
     * <p>Un compte non verifie a {@code enabled = false} : le
     * {@link org.springframework.security.authentication.DaoAuthenticationProvider}
     * leve alors {@code DisabledException}, traduite en <b>403</b> par le
     * gestionnaire d'exceptions global. Le JWT reste donc inaccessible tant que
     * l'adresse n'est pas confirmee.
     */
    @Transactional
    public AuthResponse login(LoginRequest req) {
        String email = normalize(req.email());
        // Leve BadCredentialsException si identifiants incorrects (-> 401),
        // DisabledException si le compte n'est pas encore verifie (-> 403).
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(email, req.password()));

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));

        user.setLastLoginAt(Instant.now());
        userRepository.save(user);

        return buildAuthResponse(user);
    }

    /** Renvoie les infos du compte connecte (GET /auth/me). */
    @Transactional(readOnly = true)
    public AccountResponse getAccount(UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));
        return toAccountResponse(user);
    }

    /**
     * Met a jour la photo de profil du compte connecte (tous roles). L'ancienne
     * photo (si elle etait hebergee par nous) est supprimee du disque.
     */
    @Transactional
    public AccountResponse updateAvatar(UUID userId, MultipartFile file) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));
        if (storage.kindOf(file.getContentType()) != MediaKind.IMAGE) {
            throw new BusinessException("Le fichier doit etre une image");
        }
        String old = user.getAvatarUrl();
        user.setAvatarUrl(storage.store(file));
        userRepository.save(user);
        storage.deleteByPublicUrl(old);
        return toAccountResponse(user);
    }

    /** Supprime la photo de profil du compte connecte. */
    @Transactional
    public AccountResponse removeAvatar(UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));
        String old = user.getAvatarUrl();
        user.setAvatarUrl(null);
        userRepository.save(user);
        storage.deleteByPublicUrl(old);
        return toAccountResponse(user);
    }

    /** Fabrique la reponse d'authentification (token + infos de base). */
    private AuthResponse buildAuthResponse(User user) {
        String token = jwtService.generateToken(user.getId(), user.getEmail());
        return new AuthResponse(
                token,
                "Bearer",
                jwtService.getExpirationMs(),
                user.getId(),
                user.getEmail(),
                user.getFullName());
    }

    private AccountResponse toAccountResponse(User user) {
        return new AccountResponse(
                user.getId(),
                user.getEmail(),
                user.getFullName(),
                user.getPhoneNumber(),
                user.getAvatarUrl(),
                user.getRole(),
                user.isEmailVerified(),
                user.getCreatedAt(),
                user.getLastLoginAt());
    }
}
