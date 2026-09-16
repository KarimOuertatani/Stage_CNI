package com.fitforge.api.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Configuration de Swagger / OpenAPI.
 * Definit un schema de securite "bearerAuth" (JWT) : cela fait apparaitre
 * le bouton "Authorize" dans Swagger UI, ou l'on colle le token pour tester
 * les endpoints proteges.
 */
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI fitforgeOpenApi() {
        final String scheme = "bearerAuth";
        return new OpenAPI()
                .info(new Info()
                        .title("FitForge AI - API Adherent")
                        .version("v1")
                        .description("API REST de la partie adherent : profil, entrainement, "
                                + "nutrition, score. Prete a brancher sur Flutter.")
                        .contact(new Contact().name("FitForge AI").email("contact@fitforge.tn")))
                // Applique la securite JWT globalement (tous les endpoints la demandent
                // dans l'UI ; les endpoints /auth/** restent publics cote SecurityConfig).
                .addSecurityItem(new SecurityRequirement().addList(scheme))
                .components(new Components().addSecuritySchemes(scheme,
                        new SecurityScheme()
                                .name(scheme)
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT")));
    }
}
