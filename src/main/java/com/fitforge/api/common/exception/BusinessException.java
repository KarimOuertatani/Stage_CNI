package com.fitforge.api.common.exception;

/**
 * Levee quand une regle metier est violee (ex : email deja utilise,
 * identifiants invalides, action interdite dans l'etat courant).
 * Traduite en reponse HTTP 400 par le GlobalExceptionHandler.
 */
public class BusinessException extends RuntimeException {

    public BusinessException(String message) {
        super(message);
    }
}
