package com.fitforge.api.admin.service;

import com.fitforge.api.admin.entity.AdminNotification;
import com.fitforge.api.admin.repository.AdminNotificationRepository;
import com.fitforge.api.coaching.entity.CoachProfile;
import com.fitforge.api.common.enums.AdminNotificationType;
import com.fitforge.api.user.entity.User;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

/**
 * Ecriture des notifications destinees a l'administration.
 *
 * <h2>Une notification ne doit JAMAIS faire echouer l'action qui la declenche</h2>
 * C'est la propriete centrale de ce service, et elle explique ses deux
 * particularites.
 *
 * <p>D'abord {@code Propagation.REQUIRES_NEW} : chaque ecriture se fait dans sa
 * <b>propre</b> transaction. Sans cela, une notification en echec marquerait la
 * transaction appelante comme « rollback-only », et un coach verrait sa
 * soumission de dossier refusee parce que le serveur n'a pas reussi a ecrire
 * une ligne d'information. La cause serait par ailleurs introuvable : le
 * message d'erreur parlerait de la soumission, pas de la notification.
 *
 * <p>🪤 L'annotation est posee sur <b>chaque methode publique</b>, et non sur la
 * methode privee {@code write} qu'elles partagent -- ce qui aurait pourtant ete
 * le geste naturel. Spring passe par un proxy : un appel interne a la classe ne
 * le traverse pas, et la propagation aurait ete <b>silencieusement ignoree</b>.
 * C'est le pire cas de figure, puisque le code aurait eu l'air correct.
 *
 * <p>Ensuite le {@code try/catch} : meme isolee, une exception remonterait a
 * l'appelant. Elle est donc journalisee et absorbee. Perdre une notification
 * est un inconvenient -- l'administrateur verra de toute facon le dossier dans
 * sa file d'attente, qui est calculee depuis les donnees reelles. Perdre la
 * soumission serait un defaut.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AdminNotificationService {

    private final AdminNotificationRepository repository;

    /** Un coach a soumis son dossier : il attend une decision humaine. */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void coachApplicationSubmitted(CoachProfile profile) {
        String name = profile.getUser() == null ? "Un coach" : profile.getUser().getFullName();
        write(AdminNotificationType.COACH_APPLICATION_SUBMITTED,
                "Nouvelle candidature coach",
                name + " a soumis son dossier et attend une validation.",
                profile.getId());
    }

    /** Un nouvel adherent a cree son compte. */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void memberRegistered(User user) {
        write(AdminNotificationType.MEMBER_REGISTERED,
                "Nouvel adherent",
                user.getFullName() + " vient de creer un compte.",
                user.getId());
    }

    /** Un utilisateur a signale un probleme. */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void problemReported(User reporter, String subject, UUID reportId) {
        String name = reporter == null ? "Un utilisateur" : reporter.getFullName();
        write(AdminNotificationType.PROBLEM_REPORTED,
                "Nouveau signalement",
                name + " : " + subject,
                reportId);
    }

    /**
     * Ecrit la ligne, sans jamais lever. La transaction dediee est ouverte par
     * la methode publique appelante (voir l'en-tete de classe).
     *
     * <p>Le libelle est fige ici, au moment de l'evenement -- voir la
     * documentation de {@link AdminNotification} sur ce point.
     */
    private void write(AdminNotificationType type, String title, String body, UUID targetId) {
        try {
            repository.save(AdminNotification.builder()
                    .type(type)
                    .title(title)
                    .body(body)
                    .targetId(targetId)
                    .build());
        } catch (Exception e) {
            log.warn("Notification admin non enregistree ({}) : {}", type, e.getMessage());
        }
    }

    // ── Lecture (console) ────────────────────────────────────────

    @Transactional(readOnly = true)
    public long unreadCount() {
        return repository.countByReadAtIsNull();
    }

    @Transactional
    public void markRead(UUID id) {
        repository.findById(id).ifPresent(n -> {
            if (n.getReadAt() == null) {
                n.setReadAt(Instant.now());
                repository.save(n);
            }
        });
    }

    @Transactional
    public int markAllRead() {
        return repository.markAllRead(Instant.now());
    }
}
