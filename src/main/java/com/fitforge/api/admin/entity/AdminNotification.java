package com.fitforge.api.admin.entity;

import com.fitforge.api.common.enums.AdminNotificationType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
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
 * Un evenement porte a la connaissance de l'administration.
 *
 * <h2>Pourquoi une table, et pas un simple calcul a la volee ?</h2>
 * On pourrait deduire « il y a 3 dossiers a examiner » d'un {@code count} sur
 * {@code coach_profiles}. Mais un compteur ne dit que l'etat present : il ne
 * garde aucune trace de ce qui est <b>arrive</b>, et surtout il ne peut pas
 * etre marque comme lu. Un administrateur qui a vu passer une inscription et
 * l'a traitee doit pouvoir la faire disparaitre de sa liste -- ce qui suppose
 * un enregistrement par evenement, et non un total recalcule.
 *
 * <h2>Le libelle est fige a l'ecriture</h2>
 * {@code title} et {@code body} sont rediges au moment de l'evenement et ne
 * sont plus jamais recalcules. Une notification est le recit de ce qui s'est
 * passe : si le coach change de nom trois jours plus tard, la ligne doit
 * continuer a dire ce qu'elle disait. Reconstituer le texte a l'affichage,
 * depuis les donnees actuelles, produirait un historique qui se reecrit tout
 * seul -- et des notifications vides pour les entites supprimees depuis.
 */
@Entity
@Table(name = "admin_notifications")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AdminNotification {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private AdminNotificationType type;

    @Column(nullable = false)
    private String title;

    @Column(length = 500)
    private String body;

    /**
     * Identifiant de l'objet concerne (profil coach, utilisateur, signalement),
     * pour que le clic ouvre directement la bonne fiche.
     *
     * <p>Volontairement <b>sans cle etrangere</b>. Une notification survit a ce
     * qu'elle designe : si l'objet est supprime, on veut garder la trace de
     * l'evenement et afficher un lien mort plutot que de perdre la ligne. Une
     * contrainte referentielle imposerait l'inverse.
     */
    @Column(name = "target_id")
    private UUID targetId;

    /** Null tant que la notification n'a pas ete lue. */
    @Column(name = "read_at")
    private Instant readAt;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
