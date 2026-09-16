package com.fitforge.api.user.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

/**
 * Donnees envoyees par Flutter pour creer un compte adherent.
 * La date de naissance est demandee des l'inscription : elle sert a calculer
 * l'age (puis, une fois le poids/taille renseignes dans le profil, le TDEE).
 */
@Schema(description = "Requete d'inscription d'un adherent")
public record RegisterRequest(

        @Schema(description = "Email de connexion", example = "sami@fitforge.tn")
        @NotBlank @Email
        String email,

        @Schema(description = "Mot de passe (8 caracteres minimum)", example = "MonMotDePasse123")
        @NotBlank @Size(min = 8, message = "le mot de passe doit faire au moins 8 caracteres")
        String password,

        @Schema(description = "Nom complet", example = "Sami Ben Ali")
        @NotBlank
        String fullName,

        @Schema(description = "Date de naissance", example = "1998-05-12")
        @NotNull @Past(message = "la date de naissance doit etre dans le passe")
        LocalDate birthDate,

        @Schema(description = "Telephone (optionnel)", example = "+21620123456")
        String phoneNumber
) {}
