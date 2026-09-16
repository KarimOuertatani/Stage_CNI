package com.fitforge.api.admin.service;

import com.fitforge.api.common.enums.Role;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.Locale;

/**
 * Cree le compte administrateur au demarrage s'il n'existe pas encore.
 *
 * <h2>Pourquoi pas un {@code INSERT} dans une migration Flyway ?</h2>
 * Parce qu'un mot de passe ne s'ecrit pas dans un fichier de migration. Il
 * faudrait y figer un hachage BCrypt, qui serait alors :
 * <ul>
 *   <li><b>identique sur toutes les installations</b> -- le meme mot de passe
 *       ouvrirait la console d'administration de chaque deploiement du projet ;</li>
 *   <li><b>impossible a changer</b> sans ecrire une seconde migration, alors
 *       qu'une migration deja appliquee ne se rejoue pas ;</li>
 *   <li><b>versionne pour toujours</b> dans l'historique du depot, meme apres
 *       correction.</li>
 * </ul>
 *
 * <p>Ici, le mot de passe vient de la configuration (donc d'une variable
 * d'environnement en production) et c'est l'encodeur de l'application qui le
 * hache -- le meme que pour tous les autres comptes.
 *
 * <h2>Il ne met JAMAIS a jour un compte existant</h2>
 * Si l'email est deja pris, on ne touche a rien. Un bootstrapper qui
 * reappliquerait le mot de passe de configuration a chaque demarrage annulerait
 * silencieusement tout changement de mot de passe fait depuis la console -- et
 * reinstallerait le mot de passe par defaut sur une machine ou l'administrateur
 * croyait l'avoir change.
 *
 * <h2>Le compte est cree deja verifie</h2>
 * {@code emailVerified = true} et {@code enabled = true} : l'administrateur ne
 * passe pas par la verification d'email a six chiffres, qui suppose une boite
 * aux lettres joignable. Un serveur SMTP indisponible ne doit pas pouvoir
 * bloquer l'acces a la console d'administration.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class AdminAccountBootstrapper implements ApplicationRunner {

    /**
     * Mot de passe par defaut. Sa presence dans le depot est <b>volontaire et
     * sans risque</b> tant qu'il declenche l'avertissement ci-dessous : il n'a
     * d'effet que sur une base neuve, et il est concu pour etre remplace.
     */
    static final String DEFAULT_PASSWORD = "ChangeMoi!2026";

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.admin.email:admin@fitforge.local}")
    private String adminEmail;

    @Value("${app.admin.password:" + DEFAULT_PASSWORD + "}")
    private String adminPassword;

    @Value("${app.admin.full-name:Equipe FitForge}")
    private String adminFullName;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        String email = adminEmail == null ? "" : adminEmail.trim().toLowerCase(Locale.ROOT);
        if (email.isBlank()) {
            log.warn("app.admin.email est vide : aucun compte administrateur ne sera cree.");
            return;
        }
        if (userRepository.existsByEmail(email)) {
            return; // deja present : on ne rejoue rien, on n'ecrase rien.
        }

        User admin = User.builder()
                .email(email)
                .passwordHash(passwordEncoder.encode(adminPassword))
                .fullName(adminFullName)
                .role(Role.ADMIN)
                .enabled(true)
                .emailVerified(true)
                .build();
        userRepository.save(admin);

        log.info("Compte administrateur cree : {}", email);
        if (DEFAULT_PASSWORD.equals(adminPassword)) {
            log.warn("""
                    ============================================================
                     ATTENTION - MOT DE PASSE ADMINISTRATEUR PAR DEFAUT
                     Le compte {} utilise le mot de passe livre avec le code.
                     Definis APP_ADMIN_PASSWORD (variable d'environnement) puis
                     redemarre, ou change le mot de passe depuis la console.
                    ============================================================""", email);
        }
    }
}
