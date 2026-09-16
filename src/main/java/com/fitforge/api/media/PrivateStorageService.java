package com.fitforge.api.media;

import com.fitforge.api.common.exception.BusinessException;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

/**
 * Stockage des fichiers <b>confidentiels</b> : justificatifs de candidature des
 * coachs (piece d'identite, photos de diplomes et de certificats).
 *
 * <h2>Pourquoi un second service de stockage ?</h2>
 * {@link StorageService} depose ses fichiers dans un dossier servi en HTTP sous
 * {@code /media/**}, qui est declare {@code permitAll} dans la configuration de
 * securite. C'est le bon choix pour un avatar ou une photo de chat : le lecteur
 * d'images d'une application mobile ne transmet pas le jeton JWT, et l'URL est
 * de toute facon partagee avec l'interlocuteur.
 *
 * <p>Une <b>piece d'identite</b> n'entre pas dans cette categorie. Deposee au
 * meme endroit, elle serait lisible par toute personne connaissant son URL, sans
 * aucune authentification. Le nom de fichier aleatoire ne protege rien : il rend
 * l'URL difficile a deviner, il ne la rend pas confidentielle -- elle voyage
 * dans les journaux d'acces, les historiques et les presse-papiers.
 *
 * <p>Ce service ecrit donc dans un dossier <b>que rien ne sert statiquement</b>,
 * et ne renvoie pas une URL mais une <b>cle opaque</b>. Le seul chemin de
 * lecture passe par une route authentifiee qui verifie, a chaque appel, que
 * l'appelant est l'administrateur ou le coach proprietaire du document.
 *
 * <h2>Types acceptes</h2>
 * Image ou PDF, exclusivement. Un justificatif est photographie ou scanne ; tout
 * autre type ({@code .exe}, archive, document bureautique) n'a aucune raison
 * d'etre depose ici, et l'accepter reviendrait a offrir un depot de fichiers
 * arbitraires adosse a un compte gratuit.
 */
@Service
@Slf4j
public class PrivateStorageService {

    /**
     * Taille max d'un justificatif. Volontairement bien plus basse que les 25 Mo
     * des pieces jointes du chat : une photo de diplome n'a pas besoin de plus,
     * et le plafond limite ce qu'un compte peut accumuler sur le disque.
     */
    private static final long MAX_BYTES = 10L * 1024 * 1024; // 10 Mo

    /** Types MIME acceptes pour un justificatif. */
    private static final Set<String> ALLOWED_TYPES = Set.of(
            "image/jpeg", "image/jpg", "image/png", "image/webp", "image/heic",
            "application/pdf");

    private final Path root;

    public PrivateStorageService(@Value("${app.media.private-dir:uploads-private}") String dir) {
        this.root = Paths.get(dir).toAbsolutePath().normalize();
    }

    @PostConstruct
    void init() {
        try {
            Files.createDirectories(root);
            log.info("Dossier de stockage PRIVE (justificatifs) : {}", root);
        } catch (IOException e) {
            throw new IllegalStateException("Impossible de creer le dossier prive: " + root, e);
        }
    }

    /**
     * Enregistre un justificatif et renvoie sa <b>cle de stockage</b> (le nom du
     * fichier sur disque). Cette cle n'est pas une URL et n'est jamais
     * directement joignable : elle sert d'identifiant interne, resolu par
     * {@link #load(String)} apres controle des droits.
     */
    public String store(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException("Fichier vide");
        }
        if (file.getSize() > MAX_BYTES) {
            throw new BusinessException("Fichier trop volumineux (max 10 Mo)");
        }
        String type = file.getContentType() == null
                ? "" : file.getContentType().toLowerCase(Locale.ROOT);
        if (!ALLOWED_TYPES.contains(type)) {
            throw new BusinessException(
                    "Format non accepte. Depose une photo (JPG, PNG, WEBP) ou un PDF.");
        }

        String name = UUID.randomUUID().toString().replace("-", "") + extensionOf(file.getOriginalFilename());
        Path target = root.resolve(name).normalize();
        if (!target.startsWith(root)) {
            throw new BusinessException("Chemin de fichier invalide");
        }
        try {
            Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException e) {
            throw new BusinessException("Echec de l'enregistrement du justificatif");
        }
        return name;
    }

    /**
     * Ouvre le fichier designe par une cle de stockage.
     *
     * <p>La cle vient de la base, mais elle est malgre tout re-verifiee ici : une
     * cle contenant {@code ../} permettrait de lire n'importe quel fichier du
     * serveur. Se fier a l'origine d'une valeur plutot qu'a sa forme est
     * precisement le raisonnement qui produit les traversees de repertoire.
     */
    public Resource load(String storageKey) {
        if (storageKey == null || storageKey.isBlank()) {
            throw new BusinessException("Justificatif introuvable");
        }
        Path target = root.resolve(storageKey).normalize();
        if (!target.startsWith(root) || !Files.isReadable(target)) {
            throw new BusinessException("Justificatif introuvable");
        }
        return new FileSystemResource(target);
    }

    /** Supprime un justificatif. Silencieux si le fichier n'existe plus. */
    public void delete(String storageKey) {
        if (storageKey == null || storageKey.isBlank()) return;
        Path target = root.resolve(storageKey).normalize();
        if (!target.startsWith(root)) return;
        try {
            Files.deleteIfExists(target);
        } catch (IOException e) {
            log.warn("Suppression du justificatif impossible: {}", storageKey, e);
        }
    }

    /** Extension (avec le point) tiree du nom d'origine, en minuscules ; "" sinon. */
    private String extensionOf(String original) {
        String ext = StringUtils.getFilenameExtension(original);
        if (ext == null || ext.isBlank()) return "";
        String cleaned = ext.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]", "");
        if (cleaned.isBlank() || cleaned.length() > 8) return "";
        return "." + cleaned;
    }
}
