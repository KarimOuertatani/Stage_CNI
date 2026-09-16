package com.fitforge.api.user.service;

import com.fitforge.api.common.enums.ActivityLevel;
import com.fitforge.api.common.enums.Gender;
import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.user.dto.ProfileResponse;
import com.fitforge.api.user.dto.UpdateProfileRequest;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.entity.UserProfile;
import com.fitforge.api.user.mapper.ProfileMapper;
import com.fitforge.api.user.repository.UserProfileRepository;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.Period;
import java.util.UUID;

/**
 * Logique metier du profil : lecture et mise a jour, avec recalcul automatique
 * des champs derives (age, IMC, TDEE) a chaque enregistrement.
 */
@Service
@RequiredArgsConstructor
public class ProfileService {

    private final UserProfileRepository profileRepo;
    private final UserRepository userRepo;
    private final ProfileMapper mapper;

    /** Recupere le profil de l'adherent connecte. */
    @Transactional(readOnly = true)
    public ProfileResponse getMyProfile(UUID userId) {
        UserProfile p = profileRepo.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Profil introuvable"));
        return mapper.toResponse(p);
    }

    /**
     * Cree le profil s'il n'existe pas encore, sinon le met a jour, puis
     * recalcule les champs derives. Marque l'onboarding comme termine.
     */
    @Transactional
    public ProfileResponse updateMyProfile(UUID userId, UpdateProfileRequest req) {
        // Recupere le profil existant, ou en cree un neuf rattache au compte
        UserProfile p = profileRepo.findByUserId(userId)
                .orElseGet(() -> {
                    User u = userRepo.findById(userId)
                            .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));
                    UserProfile np = new UserProfile();
                    np.setUser(u);
                    return np;
                });

        mapper.updateFromDto(req, p);   // applique les champs fournis (ignore les null)
        recomputeDerived(p);            // age + IMC + TDEE
        p.setOnboardingCompleted(true); // le profil a ete rempli au moins une fois

        return mapper.toResponse(profileRepo.save(p));
    }

    /**
     * Recalcule les champs derives du profil.
     * - age  : nombre d'annees entre la date de naissance et aujourd'hui.
     * - IMC  : poids(kg) / taille(m)^2.
     * - TDEE : BMR (Mifflin-St Jeor) x facteur d'activite (rythme de vie).
     */
    private void recomputeDerived(UserProfile p) {
        // --- Age depuis la date de naissance (l'age change tout seul) ---
        if (p.getBirthDate() != null) {
            p.setAge(Period.between(p.getBirthDate(), LocalDate.now()).getYears());
        }

        // --- IMC = poids / taille^2 (taille en metres) ---
        if (p.getHeightCm() != null && p.getCurrentWeightKg() != null && p.getHeightCm() > 0) {
            double meters = p.getHeightCm() / 100.0;
            p.setBmi(round(p.getCurrentWeightKg() / (meters * meters), 1));
        }

        // --- TDEE : depense energetique totale journaliere ---
        // 1) BMR par la formule Mifflin-St Jeor :
        //    BMR = 10*poids + 6.25*taille - 5*age (+5 homme / -161 femme)
        // 2) TDEE = BMR * facteur lie au rythme de vie.
        if (p.getHeightCm() != null && p.getCurrentWeightKg() != null
                && p.getAge() != null && p.getGender() != null) {
            double bmr = 10 * p.getCurrentWeightKg()
                    + 6.25 * p.getHeightCm()
                    - 5 * p.getAge();
            bmr += (p.getGender() == Gender.HOMME) ? 5 : -161;

            // Si le rythme de vie n'est pas renseigne, on suppose MODERE.
            ActivityLevel level = (p.getActivityLevel() == null) ? ActivityLevel.MODERE : p.getActivityLevel();
            double factor = switch (level) {
                case SEDENTAIRE -> 1.2;
                case LEGER      -> 1.375;
                case MODERE     -> 1.55;
                case ACTIF      -> 1.725;
                case TRES_ACTIF -> 1.9;
            };
            p.setTdee((int) Math.round(bmr * factor));
        }
    }

    /** Arrondit un double a n decimales (arrondi arithmetique). */
    private double round(double value, int decimals) {
        return BigDecimal.valueOf(value).setScale(decimals, RoundingMode.HALF_UP).doubleValue();
    }
}
