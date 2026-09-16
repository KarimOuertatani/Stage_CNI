package com.fitforge.api.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.nio.file.Paths;

/**
 * Exposition HTTP des fichiers uploades : le contenu du dossier de stockage
 * ({@code app.media.dir}) est servi en lecture sous le prefixe {@code /media/**}.
 * C'est ce chemin que {@link com.fitforge.api.media.StorageService} renvoie
 * apres un upload et que le front utilise pour afficher/telecharger le fichier.
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final String mediaDir;

    public WebConfig(@Value("${app.media.dir:uploads}") String mediaDir) {
        this.mediaDir = mediaDir;
    }

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        String location = Paths.get(mediaDir).toAbsolutePath().normalize().toUri().toString();
        registry.addResourceHandler("/media/**")
                .addResourceLocations(location)
                .setCachePeriod(3600);
    }
}
