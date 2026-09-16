package com.fitforge.api.user.controller;

import com.fitforge.api.coaching.dto.RegisterCoachRequest;
import com.fitforge.api.coaching.service.CoachService;
import com.fitforge.api.security.UserPrincipal;
import com.fitforge.api.user.dto.AccountResponse;
import com.fitforge.api.user.dto.AuthResponse;
import com.fitforge.api.user.dto.LoginRequest;
import com.fitforge.api.user.dto.RegisterRequest;
import com.fitforge.api.user.dto.RegistrationResponse;
import com.fitforge.api.user.dto.ResendCodeRequest;
import com.fitforge.api.user.dto.VerifyEmailRequest;
import com.fitforge.api.user.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * API d'authentification. Ces routes (/auth/**) sont publiques sauf /me.
 * Flux : register -> login (renvoie un JWT) -> Flutter met le token sur
 * chaque requete suivante.
 */
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
@Tag(name = "Authentification", description = "Inscription, connexion et compte connecte")
public class AuthController {

    private final AuthService authService;
    private final CoachService coachService;

    @PostMapping("/register")
    @Operation(
            summary = "Creer un compte adherent",
            description = """
                    Le compte est cree DESACTIVE et un code a 6 chiffres est envoye
                    par email (valable 10 minutes). Aucun token n'est renvoye ici :
                    il faut d'abord valider le code via POST /auth/verify-email.""")
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Compte cree, code envoye par email"),
            @ApiResponse(responseCode = "400", description = "Email deja utilise ou donnees invalides")
    })
    public ResponseEntity<RegistrationResponse> register(@Valid @RequestBody RegisterRequest req) {
        // 201 Created : une ressource (compte) a ete creee
        return ResponseEntity.status(HttpStatus.CREATED).body(authService.register(req));
    }

    @PostMapping("/register/coach")
    @Operation(
            summary = "Creer un compte coach",
            description = "Meme parcours que l'inscription adherent : compte desactive "
                    + "et code de verification envoye par email.")
    public ResponseEntity<RegistrationResponse> registerCoach(
            @Valid @RequestBody RegisterCoachRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(coachService.registerCoach(req));
    }

    @PostMapping("/verify-email")
    @Operation(
            summary = "Verifier l'adresse email et activer le compte",
            description = """
                    Valide le code a 6 chiffres recu par email. En cas de succes le compte
                    passe a enabled = true et le token JWT est renvoye : l'utilisateur est
                    connecte dans la foulee.
                    Le code est a usage unique, expire au bout de 10 minutes et tolere
                    5 tentatives.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Compte active, token JWT renvoye"),
            @ApiResponse(responseCode = "400", description = "Code invalide, expire ou trop de tentatives")
    })
    public AuthResponse verifyEmail(@Valid @RequestBody VerifyEmailRequest req) {
        return authService.verifyEmail(req);
    }

    @PostMapping("/resend-code")
    @Operation(
            summary = "Renvoyer un code de verification",
            description = """
                    Genere et envoie un nouveau code, au plus UN PAR MINUTE.
                    Reponse volontairement identique que l'adresse existe ou non,
                    afin de ne pas reveler quels comptes sont inscrits.""")
    @ApiResponses({
            @ApiResponse(responseCode = "204", description = "Demande prise en compte"),
            @ApiResponse(responseCode = "400", description = "Delai d'attente non ecoule, ou compte deja verifie")
    })
    public ResponseEntity<Void> resendCode(@Valid @RequestBody ResendCodeRequest req) {
        authService.resendVerificationCode(req.email());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/login")
    @Operation(
            summary = "Se connecter (renvoie un token JWT)",
            description = "Refuse avec 403 tant que l'adresse email n'a pas ete verifiee.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Connecte, token JWT renvoye"),
            @ApiResponse(responseCode = "401", description = "Email ou mot de passe incorrect"),
            @ApiResponse(responseCode = "403", description = "Compte non verifie")
    })
    public AuthResponse login(@Valid @RequestBody LoginRequest req) {
        return authService.login(req);
    }

    @GetMapping("/me")
    @Operation(summary = "Infos du compte connecte")
    public AccountResponse me(@AuthenticationPrincipal UserPrincipal me) {
        return authService.getAccount(me.getId());
    }

    @PostMapping(value = "/me/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Definir ma photo de profil (image)")
    public AccountResponse updateAvatar(
            @AuthenticationPrincipal UserPrincipal me,
            @RequestParam("file") MultipartFile file) {
        return authService.updateAvatar(me.getId(), file);
    }

    @DeleteMapping("/me/avatar")
    @Operation(summary = "Supprimer ma photo de profil")
    public AccountResponse removeAvatar(@AuthenticationPrincipal UserPrincipal me) {
        return authService.removeAvatar(me.getId());
    }
}
