package com.fitforge.api.user.entity;

import com.fitforge.api.common.enums.Role;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.util.UUID;

/**
 * Compte utilisateur = identite + authentification uniquement.
 * Les donnees physiques/sportives sont volontairement isolees dans
 * {@link UserProfile} (relation 1-1) pour ne pas surcharger cette table
 * et pouvoir faire evoluer le profil independamment du compte.
 */
@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {

    /** Identifiant technique en UUID (genere par Hibernate). */
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Email = identifiant de connexion, unique. */
    @Column(nullable = false, unique = true)
    private String email;

    /** Mot de passe HASHE (BCrypt) - jamais en clair. */
    @Column(nullable = false)
    private String passwordHash;

    @Column(nullable = false)
    private String fullName;

    /** Telephone optionnel (utile en Tunisie pour l'inscription). */
    private String phoneNumber;

    /** URL de la photo de profil. */
    private String avatarUrl;

    /** Role du compte : ADHERENT pour la partie 1. */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Role role;

    /** Compte actif ? Permet de desactiver sans supprimer. */
    @Column(nullable = false)
    @Builder.Default
    private boolean enabled = true;

    /** Email valide ? (pour un futur flux de verification d'email). */
    @Column(nullable = false)
    @Builder.Default
    private boolean emailVerified = false;

    /** Date de creation, remplie automatiquement par Hibernate a l'insert. */
    @CreationTimestamp
    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    /** Date de derniere modification, mise a jour automatiquement. */
    @UpdateTimestamp
    private Instant updatedAt;

    /** Horodatage de la derniere connexion reussie (authentification). */
    private Instant lastLoginAt;

    /**
     * Derniere activite temps reel connue : ecrite a chaque connexion et
     * deconnexion WebSocket.
     *
     * <p>Sert a afficher « Vu il y a 5 min » quand l'utilisateur n'est pas en
     * ligne. Ne pas confondre avec {@link #lastLoginAt} : un adherent peut
     * rester authentifie des semaines (JWT) sans jamais ouvrir l'application.
     */
    @Column(name = "last_seen_at")
    private Instant lastSeenAt;

    /**
     * Profil physique associe (1-1). cascade = ALL + orphanRemoval : le profil
     * suit le cycle de vie du compte (cree/supprime avec lui).
     */
    @OneToOne(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true)
    private UserProfile profile;
}
