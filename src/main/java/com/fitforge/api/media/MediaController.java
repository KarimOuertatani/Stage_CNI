package com.fitforge.api.media;

import com.fitforge.api.media.dto.MediaResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * Upload generique de fichiers (pieces jointes du chat : image, document,
 * message vocal). Renvoie l'URL publique du fichier ; l'envoi du message se
 * fait ensuite via {@code POST /coaching/{id}/messages} en referencant cette URL.
 * Authentification requise (JWT).
 */
@RestController
@RequestMapping("/api/v1/media")
@RequiredArgsConstructor
@Tag(name = "Medias", description = "Upload de fichiers (pieces jointes, avatars)")
public class MediaController {

    private final StorageService storage;

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Uploader un fichier et recuperer son URL publique")
    public ResponseEntity<MediaResponse> upload(@RequestParam("file") MultipartFile file) {
        String url = storage.store(file);
        MediaResponse body = new MediaResponse(
                url,
                file.getOriginalFilename(),
                file.getContentType(),
                file.getSize(),
                storage.kindOf(file.getContentType())
        );
        return ResponseEntity.status(HttpStatus.CREATED).body(body);
    }
}
