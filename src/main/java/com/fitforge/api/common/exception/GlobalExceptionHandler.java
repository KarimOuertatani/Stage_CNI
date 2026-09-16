package com.fitforge.api.common.exception;

import com.fitforge.api.common.dto.ApiError;
import org.springframework.http.HttpStatus;
import org.springframework.web.servlet.resource.NoResourceFoundException;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.stream.Collectors;

/**
 * Intercepte les exceptions remontant des controllers et les transforme en
 * reponses JSON coherentes ({@link ApiError}), pour que Flutter ait toujours
 * un format d'erreur previsible plutot qu'une stacktrace brute.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    /** Ressource introuvable -> 404. */
    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ApiError> handleNotFound(ResourceNotFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(ApiError.of(404, "NOT_FOUND", ex.getMessage()));
    }

    /** Regle metier violee -> 400. */
    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiError> handleBusiness(BusinessException ex) {
        return ResponseEntity.badRequest()
                .body(ApiError.of(400, "BUSINESS_ERROR", ex.getMessage()));
    }

    /**
     * Echec de validation d'un DTO d'entree (@Valid) -> 400.
     * On concatene tous les champs en erreur pour un message clair.
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex) {
        String msg = ex.getBindingResult().getFieldErrors().stream()
                .map(e -> e.getField() + " : " + e.getDefaultMessage())
                .collect(Collectors.joining(", "));
        return ResponseEntity.badRequest()
                .body(ApiError.of(400, "VALIDATION_ERROR", msg));
    }

    /** Mauvais identifiants a la connexion -> 401. */
    @ExceptionHandler(BadCredentialsException.class)
    public ResponseEntity<ApiError> handleBadCredentials(BadCredentialsException ex) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(ApiError.of(401, "BAD_CREDENTIALS", "Email ou mot de passe incorrect"));
    }

    /**
     * Compte desactive -> 403 avec un code explicite.
     *
     * <p>C'est le cas d'un compte dont l'adresse email n'a pas encore ete
     * verifiee : {@code DaoAuthenticationProvider} refuse l'authentification.
     * Le code {@code EMAIL_NOT_VERIFIED} permet a l'app Flutter de rediriger
     * automatiquement vers l'ecran de saisie du code plutot que d'afficher une
     * erreur seche.
     */
    @ExceptionHandler(DisabledException.class)
    public ResponseEntity<ApiError> handleDisabled(DisabledException ex) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
                .body(ApiError.of(403, "EMAIL_NOT_VERIFIED",
                        "Votre adresse email n'est pas encore verifiee. "
                                + "Saisissez le code recu par email."));
    }

    /** Acces a une ressource non autorisee -> 403. */
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ApiError> handleAccessDenied(AccessDeniedException ex) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
                .body(ApiError.of(403, "ACCESS_DENIED", "Acces refuse"));
    }

    /**
     * Fichier statique introuvable -> 404, et non 500.
     *
     * <p>Sans ce gestionnaire, une image absente sous {@code /media/**} (avatar
     * supprime, piece jointe effacee du disque) tombait dans le filet de
     * securite ci-dessous et repondait <b>500</b>. Deux consequences, toutes
     * deux mauvaises :
     *
     * <ul>
     *   <li>une donnee manquante etait signalee comme une <b>panne du
     *       serveur</b> — ce qui pousse a chercher un probleme la ou il n'y en
     *       a pas ;</li>
     *   <li>le message interne de Spring ({@code No static resource ...})
     *       partait au client, alors qu'il decrit une organisation interne.</li>
     * </ul>
     *
     * <p>Le message renvoye reste volontairement vague : confirmer qu'un
     * fichier precis n'existe pas renseignerait sur ceux qui existent.
     */
    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ApiError> handleNoResource(NoResourceFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(ApiError.of(404, "NOT_FOUND", "Ressource introuvable"));
    }

    /** Filet de securite : toute autre exception non prevue -> 500. */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> handleGeneric(Exception ex) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiError.of(500, "INTERNAL_ERROR",
                        "Une erreur interne est survenue : " + ex.getMessage()));
    }
}
