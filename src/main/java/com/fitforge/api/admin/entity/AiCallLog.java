package com.fitforge.api.admin.entity;

import com.fitforge.api.common.enums.AiFeature;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

/**
 * Trace d'un appel a un modele de langage : quelle fonction, combien de temps,
 * et si ca a marche.
 *
 * <h2>Ce qui n'est PAS enregistre</h2>
 * Ni la question posee, ni la reponse, ni la photo, ni l'enregistrement audio,
 * ni meme l'identifiant de l'utilisateur.
 *
 * <p>Ce n'est pas une precaution de facade : ces appels transportent ce qu'un
 * adherent mange, ses blessures, ce qu'il demande a un coach. Les conserver
 * pour produire un graphique de latence serait hors de proportion avec le
 * besoin -- et creerait un journal de conversations la ou le projet a
 * precisement evite d'en avoir un (voir {@code AiCoachMessage}, dont les
 * colonnes {@code topic} et {@code refused} existent justement pour verifier le
 * perimetre <b>sans relire</b> les echanges).
 *
 * <p>Une ligne d'ici ne repond qu'a trois questions : <b>quelle</b> fonction,
 * <b>combien de temps</b>, <b>quelle erreur</b>. C'est tout ce qu'une page de
 * supervision a besoin de savoir.
 *
 * <h2>Le type d'erreur, pas le message</h2>
 * {@code errorType} porte un nom de classe ou un code HTTP, jamais le corps de
 * la reponse : Google y reprend parfois la cle d'API fournie. Le projet
 * applique deja cette regle dans les clients, qui journalisent le code HTTP
 * seul -- la respecter ici aussi evite que la base devienne l'endroit ou la
 * cle finit par fuiter.
 */
@Entity
@Table(name = "ai_call_logs")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AiCallLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private AiFeature feature;

    @Column(nullable = false)
    private boolean success;

    /** Duree de l'appel, du depart de la requete au retour du modele. */
    @Column(name = "latency_ms", nullable = false)
    private long latencyMs;

    /** Nature de l'echec (nom de classe ou code HTTP). Null si succes. */
    @Column(name = "error_type", length = 120)
    private String errorType;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
