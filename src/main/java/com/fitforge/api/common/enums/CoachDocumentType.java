package com.fitforge.api.common.enums;

/**
 * Nature d'un justificatif depose par un coach a l'appui de sa candidature.
 *
 * <p>Le type n'est pas decoratif : c'est lui qui permet a l'administrateur de
 * savoir <b>ce qu'il regarde</b> sans ouvrir chaque fichier, et au serveur de
 * verifier qu'un dossier est complet avant d'accepter la soumission. Un dossier
 * de dix photos de diplomes sans piece d'identite ne permet aucune verification
 * de fraude : rien ne relie les documents au titulaire du compte.
 */
public enum CoachDocumentType {

    /**
     * Piece d'identite. <b>Obligatoire</b>, et en un seul exemplaire utile.
     * C'est la seule piece qui rattache les diplomes a la personne : sans elle,
     * n'importe qui peut deposer la photo du diplome de n'importe qui d'autre.
     */
    IDENTITY,

    /** Photo ou scan d'un diplome (STAPS, licence, master...). */
    DIPLOMA,

    /** Photo ou scan d'une certification professionnelle (BPJEPS, CQP...). */
    CERTIFICATION,

    /** Autre justificatif : attestation d'assurance, carte professionnelle... */
    OTHER
}
