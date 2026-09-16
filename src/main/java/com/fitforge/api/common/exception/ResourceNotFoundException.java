package com.fitforge.api.common.exception;

/**
 * Levee quand une ressource demandee n'existe pas (profil, programme, log...).
 * Traduite en reponse HTTP 404 par le GlobalExceptionHandler.
 */
public class ResourceNotFoundException extends RuntimeException {

    public ResourceNotFoundException(String message) {
        super(message);
    }
}
