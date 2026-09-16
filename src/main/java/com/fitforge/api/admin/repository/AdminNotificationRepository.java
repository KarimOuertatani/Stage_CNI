package com.fitforge.api.admin.repository;

import com.fitforge.api.admin.entity.AdminNotification;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.time.Instant;
import java.util.UUID;

/** Acces base pour les notifications de la console d'administration. */
public interface AdminNotificationRepository extends JpaRepository<AdminNotification, UUID> {

    Page<AdminNotification> findAllByOrderByCreatedAtDesc(Pageable pageable);

    Page<AdminNotification> findByReadAtIsNullOrderByCreatedAtDesc(Pageable pageable);

    long countByReadAtIsNull();

    /**
     * Marque toutes les notifications non lues comme lues, en une seule requete.
     *
     * <p>Les charger pour les modifier une par une ferait autant d'UPDATE que de
     * lignes -- sur une console laissee ouverte une semaine, c'est le bouton
     * « tout marquer comme lu » qui deviendrait le point lent de l'interface.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update AdminNotification n set n.readAt = :now where n.readAt is null")
    int markAllRead(Instant now);
}
