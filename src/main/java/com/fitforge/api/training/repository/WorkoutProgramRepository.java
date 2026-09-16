package com.fitforge.api.training.repository;

import com.fitforge.api.training.entity.WorkoutProgram;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.UUID;

/**
 * Acces base pour les programmes d'entrainement.
 */
public interface WorkoutProgramRepository extends JpaRepository<WorkoutProgram, UUID> {

    /** Programmes d'un adherent, les plus recents d'abord (par id de creation). */
    List<WorkoutProgram> findByUserIdOrderByTitleAsc(UUID userId);

    /** Programmes qu'un coach a crees pour un adherent donne. */
    List<WorkoutProgram> findByUserIdAndCreatedByIdOrderByTitleAsc(UUID userId, UUID createdById);

    /**
     * Programmes "prets a l'emploi" : modeles partages (is_template = true) sans
     * proprietaire (user = null). Visibles par tous les adherents. JPQL explicite
     * pour eviter toute ambiguite de derivation sur le booleen "isTemplate".
     */
    @Query("select p from WorkoutProgram p where p.isTemplate = true and p.user is null order by p.title asc")
    List<WorkoutProgram> findTemplates();
}
