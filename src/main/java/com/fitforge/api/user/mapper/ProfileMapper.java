package com.fitforge.api.user.mapper;

import com.fitforge.api.user.dto.ProfileResponse;
import com.fitforge.api.user.dto.UpdateProfileRequest;
import com.fitforge.api.user.entity.UserProfile;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingTarget;
import org.mapstruct.NullValuePropertyMappingStrategy;

/**
 * Mapping MapStruct entre l'entite {@link UserProfile} et ses DTO.
 * componentModel = spring : le mapper devient un bean injectable.
 * nullValuePropertyMappingStrategy = IGNORE : lors d'une mise a jour, un champ
 * null dans la requete NE remplace PAS la valeur existante (mise a jour partielle).
 */
@Mapper(componentModel = "spring",
        nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
public interface ProfileMapper {

    /** Entite -> reponse. fullName et avatarUrl proviennent du compte lie. */
    @Mapping(target = "fullName", source = "user.fullName")
    @Mapping(target = "avatarUrl", source = "user.avatarUrl")
    ProfileResponse toResponse(UserProfile profile);

    /**
     * Applique les champs du DTO sur une entite existante.
     * Les champs derives (age/bmi/tdee), le compte, l'id et les timestamps ne
     * sont jamais ecrases ici : ils sont geres par le service.
     */
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "user", ignore = true)
    @Mapping(target = "age", ignore = true)
    @Mapping(target = "bmi", ignore = true)
    @Mapping(target = "tdee", ignore = true)
    @Mapping(target = "onboardingCompleted", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    void updateFromDto(UpdateProfileRequest dto, @MappingTarget UserProfile profile);
}
