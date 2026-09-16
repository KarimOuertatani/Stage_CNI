package com.fitforge.api.user.repository;

import com.fitforge.api.user.entity.UserProfile;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

/**
 * Acces base pour les profils physiques/sportifs.
 */
public interface UserProfileRepository extends JpaRepository<UserProfile, UUID> {

    /** Recupere le profil d'un utilisateur a partir de l'id du compte. */
    Optional<UserProfile> findByUserId(UUID userId);
}
