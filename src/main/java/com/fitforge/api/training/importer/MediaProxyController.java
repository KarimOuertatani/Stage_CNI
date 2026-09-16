package com.fitforge.api.training.importer;

import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

import java.net.URI;
import java.time.Duration;
import java.util.concurrent.TimeUnit;

/**
 * Proxy des medias ExerciseDB (images + videos) servis par le CDN
 * {@code cdn.exercisedb.dev}.
 *
 * <p><b>Pourquoi ?</b> L'appareil mobile joint toujours notre backend (LAN /
 * domaine de prod) mais pas forcement l'Internet public du CDN (Wi-Fi de dev
 * sans acces Internet, DNS filtre...). En faisant transiter les medias par
 * notre serveur, images et videos s'affichent de maniere fiable, et l'app reste
 * totalement independante de l'accessibilite directe du CDN.
 *
 * <p><b>Securite :</b> l'hote cible est fige a {@code cdn.exercisedb.dev} (le
 * client ne fournit que le chemin) — pas de SSRF vers un hote arbitraire.
 * L'endpoint est public (permitAll) car {@code Image.network} / le lecteur video
 * ne transmettent pas le JWT.
 *
 * <p>Le {@code Range} est relaye (206 Partial Content) pour permettre le
 * streaming/seek des videos.
 */
@RestController
@RequestMapping("/api/v1/cdn")
@Slf4j
public class MediaProxyController {

    private static final String CDN_BASE = "https://cdn.exercisedb.dev/";
    private static final String PREFIX = "/api/v1/cdn/";

    private final RestClient restClient = RestClient.builder()
            .requestFactory(factory())
            .build();

    private static org.springframework.http.client.ClientHttpRequestFactory factory() {
        var f = new org.springframework.http.client.SimpleClientHttpRequestFactory();
        f.setConnectTimeout((int) Duration.ofSeconds(10).toMillis());
        f.setReadTimeout((int) Duration.ofSeconds(30).toMillis());
        return f;
    }

    @GetMapping("/**")
    public ResponseEntity<byte[]> proxy(
            HttpServletRequest request,
            @RequestHeader(value = HttpHeaders.RANGE, required = false) String range) {

        String uri = request.getRequestURI();
        int idx = uri.indexOf(PREFIX);
        if (idx < 0) {
            return ResponseEntity.notFound().build();
        }
        String path = uri.substring(idx + PREFIX.length());
        String query = request.getQueryString();
        String target = CDN_BASE + path + (query != null ? "?" + query : "");

        try {
            var spec = restClient.get().uri(URI.create(target));
            if (range != null && !range.isBlank()) {
                spec = spec.header(HttpHeaders.RANGE, range);
            }
            ResponseEntity<byte[]> upstream = spec.retrieve().toEntity(byte[].class);

            HttpHeaders headers = new HttpHeaders();
            MediaType contentType = upstream.getHeaders().getContentType();
            headers.setContentType(contentType != null ? contentType : MediaType.APPLICATION_OCTET_STREAM);
            headers.add(HttpHeaders.ACCEPT_RANGES, "bytes");
            headers.setCacheControl(CacheControl.maxAge(7, TimeUnit.DAYS).cachePublic());
            String contentRange = upstream.getHeaders().getFirst(HttpHeaders.CONTENT_RANGE);
            if (contentRange != null) {
                headers.add(HttpHeaders.CONTENT_RANGE, contentRange);
            }
            return new ResponseEntity<>(upstream.getBody(), headers, upstream.getStatusCode());
        } catch (RestClientResponseException e) {
            // Erreur renvoyee par le CDN (404, 403...) : on la relaie telle quelle.
            return ResponseEntity.status(e.getStatusCode()).build();
        } catch (Exception e) {
            log.warn("Proxy media echec pour {} : {}", target, e.getMessage());
            return ResponseEntity.status(502).build();
        }
    }
}
