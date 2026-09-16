package com.fitforge.api.config;

import com.fitforge.api.security.CustomUserDetailsService;
import com.fitforge.api.security.JwtAuthenticationFilter;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * Configuration centrale de la securite (Spring Security 6/7, syntaxe lambda).
 *
 * Principe : API stateless (pas de session), authentification par JWT.
 * - /auth/** et la doc Swagger sont publics.
 * - tout le reste exige un token valide.
 * Le {@link JwtAuthenticationFilter} s'execute avant le filtre standard pour
 * authentifier la requete a partir du token.
 */
@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final CustomUserDetailsService userDetailsService;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                // API REST sans cookies de session -> CSRF inutile
                .csrf(AbstractHttpConfigurer::disable)
                // Active la config CORS definie dans CorsConfig
                .cors(Customizer.withDefaults())
                // Aucune session cote serveur : chaque requete se re-authentifie via JWT
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        // Routes publiques : inscription/connexion + documentation
                        // + handshake WebSocket (auth faite au CONNECT STOMP via JWT)
                        .requestMatchers(
                                "/api/v1/auth/**",
                                "/ws/**",
                                // Fichiers uploades servis statiquement (avatars, pieces jointes)
                                "/media/**",
                                // Proxy des medias ExerciseDB (images/videos) : public car
                                // Image.network / le lecteur video ne transmettent pas le JWT.
                                "/api/v1/cdn/**",
                                "/swagger-ui/**", "/swagger-ui.html", "/v3/api-docs/**"
                        ).permitAll()
                        // ── Administration ───────────────────────────────────
                        //
                        // L'ORDRE COMPTE : Spring Security retient la PREMIERE
                        // regle qui correspond. La regle la plus permissive doit
                        // donc etre declaree AVANT la regle generale, sinon elle
                        // ne serait jamais atteinte.
                        //
                        // 1) L'import/enrichissement du referentiel ExerciseDB est
                        //    un outil d'exploitation, pas une decision
                        //    d'administration : un coach peut l'utiliser.
                        .requestMatchers("/api/v1/admin/exercises/**").hasAnyRole("ADMIN", "COACH")
                        // 2) TOUT le reste de /admin est reserve au seul ADMIN.
                        //    Cette regle etait auparavant "hasAnyRole(ADMIN, COACH)"
                        //    pour la seule raison que l'import y vivait. La laisser
                        //    ainsi aurait permis a un coach d'appeler les routes de
                        //    moderation -- donc de VALIDER SA PROPRE CANDIDATURE.
                        .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                        // Tout le reste exige un token valide
                        .anyRequest().authenticated()
                )
                .authenticationProvider(authenticationProvider())
                // Notre filtre JWT s'execute avant le filtre login standard
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    /** Encodeur de mots de passe : BCrypt (hash sale, resistant au brute force). */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /**
     * Fournisseur d'authentification par base : verifie l'email (via
     * CustomUserDetailsService) et le mot de passe (via BCrypt). Utilise au login.
     */
    @Bean
    public DaoAuthenticationProvider authenticationProvider() {
        DaoAuthenticationProvider provider = new DaoAuthenticationProvider(userDetailsService);
        provider.setPasswordEncoder(passwordEncoder());
        return provider;
    }

    /** Expose l'AuthenticationManager pour l'utiliser dans le service d'auth (login). */
    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }
}
