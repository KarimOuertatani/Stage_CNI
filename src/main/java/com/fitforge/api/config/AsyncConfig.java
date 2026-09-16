package com.fitforge.api.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.Executor;

/**
 * Active l'execution asynchrone ({@code @Async}).
 *
 * <p>Sert a l'envoi des emails : un aller-retour SMTP prend facilement une a
 * deux secondes. Sans {@code @Async}, l'inscription ferait patienter
 * l'utilisateur pendant tout ce temps. On repond immediatement et l'email
 * part en tache de fond.
 *
 * <p>Le pool est volontairement modeste : l'envoi d'emails est rare et une
 * file d'attente vaut mieux qu'une explosion de threads.
 */
@Configuration
@EnableAsync
public class AsyncConfig {

    /** Pool dedie aux emails (nomme pour etre identifiable dans les logs). */
    @Bean(name = "mailExecutor")
    public Executor mailExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(2);
        executor.setMaxPoolSize(5);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("mail-");
        // Laisse le temps aux envois en cours de se terminer a l'arret.
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(15);
        executor.initialize();
        return executor;
    }
}
