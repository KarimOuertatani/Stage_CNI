package com.fitforge.api.media;

import com.fitforge.api.common.enums.MediaKind;
import com.fitforge.api.common.exception.BusinessException;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Locale;
import java.util.UUID;

/**
 * Stockage des fichiers uploades (avatars, pieces jointes du chat) sur le
 * disque local, dans un dossier configurable ({@code app.media.dir}).
 *
 * Les fichiers sont servis en HTTP par {@code WebConfig} sous le prefixe
 * {@code /media/**}. On renvoie donc un chemin RELATIF ({@code /media/<nom>})
 * que le front resout contre l'hote de l'API (portable emulateur/appareil).
 */
@Service
@Slf4j
public class StorageService {

    /** Prefixe public sous lequel les fichiers sont exposes. */
    public static final String PUBLIC_PREFIX = "/media/";

    /** Taille max acceptee (garde-fou en plus de la limite multipart). */
    private static final long MAX_BYTES = 25L * 1024 * 1024; // 25 Mo

    private final Path root;

    public StorageService(@Value("${app.media.dir:uploads}") String dir) {
        this.root = Paths.get(dir).toAbsolutePath().normalize();
    }

    @PostConstruct
    void init() {
        try {
            Files.createDirectories(root);
            log.info("Dossier de stockage des medias : {}", root);
        } catch (IOException e) {
            throw new IllegalStateException("Impossible de creer le dossier de stockage: " + root, e);
        }
    }

    /**
     * Enregistre le fichier et renvoie son URL publique relative.
     * Le nom sur disque est aleatoire (UUID) pour eviter collisions et fuite
     * d'information ; l'extension d'origine est conservee.
     */
    public String store(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException("Fichier vide");
        }
        if (file.getSize() > MAX_BYTES) {
            throw new BusinessException("Fichier trop volumineux (max 25 Mo)");
        }

        String ext = extensionOf(file.getOriginalFilename());
        String name = UUID.randomUUID().toString().replace("-", "") + ext;
        Path target = root.resolve(name).normalize();

        // Securite : le chemin cible doit rester sous la racine.
        if (!target.startsWith(root)) {
            throw new BusinessException("Chemin de fichier invalide");
        }

        try {
            Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException e) {
            throw new BusinessException("Echec de l'enregistrement du fichier");
        }
        return PUBLIC_PREFIX + name;
    }

    /** Supprime le fichier designe par une URL publique ({@code /media/<nom>}). */
    public void deleteByPublicUrl(String publicUrl) {
        if (publicUrl == null || !publicUrl.startsWith(PUBLIC_PREFIX)) return;
        String name = publicUrl.substring(PUBLIC_PREFIX.length());
        Path target = root.resolve(name).normalize();
        if (!target.startsWith(root)) return;
        try {
            Files.deleteIfExists(target);
        } catch (IOException e) {
            log.warn("Suppression du media impossible: {}", name, e);
        }
    }

    /** Deduit la nature (IMAGE/AUDIO/FILE) depuis le type MIME. */
    public MediaKind kindOf(String contentType) {
        if (contentType == null) return MediaKind.FILE;
        String c = contentType.toLowerCase(Locale.ROOT);
        if (c.startsWith("image/")) return MediaKind.IMAGE;
        if (c.startsWith("audio/")) return MediaKind.AUDIO;
        return MediaKind.FILE;
    }

    /** Extension (avec le point) tiree du nom d'origine, en minuscules ; "" sinon. */
    private String extensionOf(String original) {
        String ext = StringUtils.getFilenameExtension(original);
        if (ext == null || ext.isBlank()) return "";
        // On ne garde que des extensions alphanumeriques raisonnables.
        String cleaned = ext.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]", "");
        if (cleaned.isBlank() || cleaned.length() > 8) return "";
        return "." + cleaned;
    }
}
