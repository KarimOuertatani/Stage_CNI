package com.fitforge.api.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;

/**
 * Service de gestion des tokens JWT (jjwt 0.12.x).
 * - Genere un token signe (HMAC-SHA256) dont le "subject" est l'id du compte.
 * - Verifie et lit un token pour en extraire l'id.
 *
 * La cle et la duree de vie viennent de application.yaml (app.jwt.*).
 */
@Service
public class JwtService {

    private final SecretKey signingKey;
    private final long expirationMs;

    public JwtService(
            @Value("${app.jwt.secret}") String secret,
            @Value("${app.jwt.expiration-ms}") long expirationMs) {
        // La cle Base64 est decodee en octets puis transformee en cle HMAC.
        this.signingKey = Keys.hmacShaKeyFor(Decoders.BASE64.decode(secret));
        this.expirationMs = expirationMs;
    }

    /**
     * Genere un token pour un utilisateur donne.
     * Le "subject" contient l'id (UUID) : c'est ce qu'on relira pour savoir
     * qui fait la requete.
     */
    public String generateToken(UUID userId, String email) {
        Instant now = Instant.now();
        Instant expiry = now.plusMillis(expirationMs);
        return Jwts.builder()
                .subject(userId.toString())
                .claim("email", email)
                .issuedAt(Date.from(now))
                .expiration(Date.from(expiry))
                .signWith(signingKey)
                .compact();
    }

    /** Extrait l'id du compte (subject) apres avoir verifie la signature. */
    public UUID extractUserId(String token) {
        return UUID.fromString(parseClaims(token).getSubject());
    }

    /**
     * Verifie qu'un token est valide (signature correcte + non expire).
     * Retourne false sur toute exception (token invalide, expire, malforme).
     */
    public boolean isTokenValid(String token) {
        try {
            parseClaims(token);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /** Duree de vie du token en millisecondes (expose pour la reponse de login). */
    public long getExpirationMs() {
        return expirationMs;
    }

    /** Parse et VERIFIE le token ; leve une exception si invalide. */
    private Claims parseClaims(String token) {
        return Jwts.parser()
                .verifyWith(signingKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}
