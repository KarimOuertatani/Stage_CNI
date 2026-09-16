package com.fitforge.api.admin.service;

import com.fitforge.api.admin.dto.AdminUserDetail;
import com.fitforge.api.admin.dto.AdminUserSummary;
import com.fitforge.api.admin.repository.AdminStatsRepository;
import com.fitforge.api.coaching.entity.CoachProfile;
import com.fitforge.api.coaching.repository.CoachProfileRepository;
import com.fitforge.api.common.dto.PageResponse;
import com.fitforge.api.common.enums.Role;
import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.entity.UserProfile;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Locale;
import java.util.UUID;

/**
 * Gestion des comptes depuis la console.
 *
 * <h2>Suspendre, jamais supprimer</h2>
 * La seule action destructive exposee est la <b>suspension</b>, qui est
 * reversible et ne perd rien. Aucune route de suppression n'est offerte, et
 * c'est un choix : effacer un compte cascade sur ses seances, ses repas, ses
 * nuits, ses messages de chat et ses relations de suivi -- y compris cote
 * coach, qui verrait un adherent disparaitre de son suivi sans explication.
 * Un tel geste ne doit pas se trouver a portee de clic dans une liste, a cote
 * d'un bouton « suspendre » qui lui ressemble.
 *
 * <p>Le jour ou une demande d'effacement (RGPD) devra etre honoree, elle
 * meritera sa propre procedure, avec confirmation forte et journalisation --
 * pas une reutilisation de cet ecran.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AdminUserService {

    private final UserRepository userRepository;
    private final CoachProfileRepository coachProfileRepo;
    private final AdminStatsRepository stats;

    // ── Consultation ─────────────────────────────────────────────

    @Transactional(readOnly = true)
    public PageResponse<AdminUserSummary> list(
            Role role, Boolean enabled, String query, int page, int size) {

        Pageable pageable = PageRequest.of(
                Math.max(page, 0), Math.clamp(size, 1, 100),
                // Les derniers inscrits en premier : c'est ce qu'on vient
                // regarder quand on ouvre la liste sans chercher personne.
                Sort.by(Sort.Direction.DESC, "createdAt"));

        Page<User> result = userRepository.search(role, enabled, likePattern(query), pageable);
        return PageResponse.of(result, this::toSummary);
    }

    @Transactional(readOnly = true)
    public AdminUserDetail detail(UUID userId) {
        User user = load(userId);
        UserProfile p = user.getProfile();
        CoachProfile coach = user.getRole() == Role.COACH
                ? coachProfileRepo.findByUserId(userId).orElse(null)
                : null;

        return new AdminUserDetail(
                user.getId(), user.getFullName(), user.getEmail(), user.getPhoneNumber(),
                user.getAvatarUrl(), user.getRole(), user.isEnabled(), user.isEmailVerified(),
                user.getCreatedAt(), user.getLastLoginAt(), user.getLastSeenAt(),

                p == null ? null : p.getGender(),
                p == null ? null : p.getBirthDate(),
                p == null ? null : p.getAge(),
                p == null ? null : p.getHeightCm(),
                p == null ? null : p.getCurrentWeightKg(),
                p == null ? null : p.getGoal(),
                p != null && p.isOnboardingCompleted(),

                coach == null ? null : coach.getStatus(),
                coach == null ? null : coach.getId(),

                stats.countWorkoutLogs(userId),
                stats.lastWorkoutDate(userId),
                stats.countNutritionEntries(userId),
                stats.countSleepEntries(userId),
                stats.countPrograms(userId));
    }

    // ── Actions ──────────────────────────────────────────────────

    /**
     * Suspend un compte : il ne peut plus se connecter, rien n'est efface.
     *
     * <p>La suspension passe par {@code enabled = false}, le meme drapeau que
     * celui d'un email non verifie. Ce n'est pas un raccourci : c'est
     * exactement ce que Spring Security consulte
     * ({@code DaoAuthenticationProvider} leve {@code DisabledException}, traduite
     * en 403). Introduire un second drapeau « suspendu » aurait cree deux
     * facons d'etre bloque, dont une seule serait verifiee a la connexion.
     *
     * <p>⚠️ Le JWT deja emis reste techniquement valide jusqu'a son expiration
     * (24 h) : l'application est sans session serveur. La suspension empeche
     * donc toute <b>nouvelle</b> connexion, et l'acces cesse au plus tard le
     * lendemain. Pour une exclusion immediate, il faudrait une liste de
     * revocation -- une infrastructure que le besoin actuel ne justifie pas.
     */
    @Transactional
    public AdminUserDetail suspend(UUID adminId, UUID userId) {
        User user = load(userId);

        // Un administrateur qui se suspend lui-meme se ferme la console, sans
        // aucun moyen de revenir en arriere depuis l'interface.
        if (user.getId().equals(adminId)) {
            throw new BusinessException("Tu ne peux pas suspendre ton propre compte.");
        }
        if (user.getRole() == Role.ADMIN) {
            throw new BusinessException("Un compte administrateur ne peut pas etre suspendu depuis la console.");
        }
        if (!user.isEnabled()) {
            throw new BusinessException("Ce compte est deja inactif.");
        }

        user.setEnabled(false);
        userRepository.save(user);
        log.info("Compte SUSPENDU : {} par admin {}", userId, adminId);
        return detail(userId);
    }

    /**
     * Reactive un compte suspendu.
     *
     * <p>Refuse si l'email n'a jamais ete verifie : {@code enabled} serait alors
     * a {@code false} pour une raison qui n'a rien a voir avec une sanction, et
     * « reactiver » reviendrait a contourner la verification d'adresse. La
     * personne doit passer par le code a six chiffres, comme tout le monde.
     */
    @Transactional
    public AdminUserDetail reactivate(UUID adminId, UUID userId) {
        User user = load(userId);
        if (user.isEnabled()) {
            throw new BusinessException("Ce compte est deja actif.");
        }
        if (!user.isEmailVerified()) {
            throw new BusinessException(
                    "Ce compte n'a jamais verifie son adresse email : il doit le faire lui-meme, "
                            + "la reactivation ne remplace pas la verification.");
        }

        user.setEnabled(true);
        userRepository.save(user);
        log.info("Compte REACTIVE : {} par admin {}", userId, adminId);
        return detail(userId);
    }

    // ── Interne ──────────────────────────────────────────────────

    /**
     * Construit le motif {@code LIKE} de la recherche, en minuscules.
     *
     * <p>Renvoie {@code "%"} quand rien n'est cherche — ce qui laisse tout
     * passer — plutot que {@code null}.
     *
     * <p>Ce n'est pas un detail de style : un parametre nul n'a aucun type pour
     * PostgreSQL, et place dans un {@code lower(...)} il faisait echouer la
     * requete entiere avec « function lower(bytea) does not exist ». La liste
     * des membres etait donc inutilisable, y compris — et surtout — sans aucun
     * filtre. Voir {@code UserRepository.search}.
     *
     * <p>Les caracteres speciaux de {@code LIKE} sont neutralises : sans cela,
     * chercher « 100% » ou un underscore renverrait n'importe quoi.
     */
    private static String likePattern(String query) {
        if (query == null || query.isBlank()) {
            return "%";
        }
        // L'ordre compte : la barre oblique inverse doit etre doublee EN
        // PREMIER, sinon on echapperait ensuite les echappements qu'on vient
        // de poser.
        String escaped = query.trim()
                .toLowerCase(Locale.ROOT)
                .replace("\\", "\\\\")
                .replace("%", "\\%")
                .replace("_", "\\_");
        return "%" + escaped + "%";
    }

    private User load(UUID userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Compte introuvable"));
    }

    private AdminUserSummary toSummary(User u) {
        // Le statut coach n'est charge que pour les coachs : le demander pour
        // chaque adherent ferait une requete par ligne du tableau.
        var coachStatus = u.getRole() == Role.COACH
                ? coachProfileRepo.findByUserId(u.getId()).map(CoachProfile::getStatus).orElse(null)
                : null;

        return new AdminUserSummary(
                u.getId(), u.getFullName(), u.getEmail(), u.getAvatarUrl(), u.getRole(),
                u.isEnabled(), u.isEmailVerified(), coachStatus,
                u.getCreatedAt(), u.getLastLoginAt());
    }
}
