package com.fitforge.api.user.service;

import jakarta.mail.internet.MimeMessage;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.Context;

import java.nio.charset.StandardCharsets;

/**
 * Envoi des emails transactionnels (SMTP).
 *
 * <p><b>Asynchrone.</b> Un aller-retour SMTP prend une a deux secondes :
 * {@code @Async} evite de faire patienter l'utilisateur pendant son
 * inscription. La reponse HTTP part immediatement, l'email suit.
 *
 * <p><b>Securite.</b> Les identifiants SMTP viennent de la configuration
 * ({@code MAIL_USERNAME} / {@code MAIL_APP_PASSWORD}) et ne sont ni lus ni
 * journalises ici : {@link JavaMailSender} les detient. Les logs ne
 * contiennent que l'adresse du destinataire, jamais le code de verification
 * ni le mot de passe d'application.
 *
 * <p><b>Tolerance aux pannes.</b> Une erreur d'envoi est journalisee mais
 * n'interrompt rien : le compte reste cree et l'utilisateur peut demander un
 * nouveau code. Faire echouer l'inscription parce que le SMTP est
 * momentanement indisponible serait bien pire.
 */
@Service
@Slf4j
public class EmailService {

    private final JavaMailSender mailSender;
    private final TemplateEngine templateEngine;
    private final String fromAddress;
    private final String fromName;

    public EmailService(
            JavaMailSender mailSender,
            TemplateEngine templateEngine,
            @Value("${app.mail.from:${spring.mail.username:}}") String fromAddress,
            @Value("${app.mail.from-name:FitForge AI}") String fromName) {
        this.mailSender = mailSender;
        this.templateEngine = templateEngine;
        this.fromAddress = fromAddress;
        this.fromName = fromName;
    }

    /**
     * Envoie le code de verification a 6 chiffres, au format HTML.
     *
     * @param to             adresse du destinataire
     * @param fullName       nom affiche dans l'email
     * @param code           code a 6 chiffres (present uniquement dans le corps du mail)
     * @param expiryMinutes  duree de validite annoncee
     */
    @Async("mailExecutor")
    public void sendVerificationCode(String to, String fullName, String code, int expiryMinutes) {
        try {
            Context context = new Context();
            context.setVariable("fullName", fullName);
            context.setVariable("code", code);
            context.setVariable("expiryMinutes", expiryMinutes);

            String html = templateEngine.process("email/verification", context);

            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(
                    message, MimeMessageHelper.MULTIPART_MODE_NO, StandardCharsets.UTF_8.name());
            helper.setTo(to);
            helper.setSubject("Votre code de verification FitForge");
            helper.setText(html, true);   // true = corps HTML
            if (fromAddress != null && !fromAddress.isBlank()) {
                helper.setFrom(fromAddress, fromName);
            }

            mailSender.send(message);
            // On journalise le destinataire, JAMAIS le code.
            log.info("Email de verification envoye a {}", mask(to));

        } catch (Exception e) {
            // Message d'erreur seul : la trace complete de JavaMail peut
            // contenir des elements de la configuration SMTP.
            log.error("Echec de l'envoi de l'email de verification a {} : {}",
                    mask(to), e.getMessage());
        }
    }

    /**
     * Annonce a un coach que sa candidature est validee et son compte actif.
     *
     * <p>Envoye par {@code AdminCoachApplicationService} au moment de
     * l'approbation. Comme tous les envois de cette classe, il est asynchrone
     * et son echec n'annule rien : le coach est approuve en base meme si le
     * serveur SMTP est injoignable, et il le verra en ouvrant l'application.
     * L'inverse -- annuler une approbation parce qu'un email n'est pas parti --
     * serait absurde.
     */
    @Async("mailExecutor")
    public void sendCoachApproved(String to, String fullName) {
        try {
            Context context = new Context();
            context.setVariable("fullName", fullName);
            send(to, "Votre compte coach FitForge est active",
                    templateEngine.process("email/coach-approved", context));
            log.info("Email d'activation coach envoye a {}", mask(to));
        } catch (Exception e) {
            log.error("Echec de l'envoi de l'email d'activation coach a {} : {}",
                    mask(to), e.getMessage());
        }
    }

    /**
     * Annonce a un coach que son dossier doit etre corrige, en lui transmettant
     * le motif ecrit par l'administrateur.
     *
     * <p>Le motif est le contenu utile de cet email : sans lui, le coach
     * resoumettrait le meme dossier et serait refuse a l'identique. Il est
     * insere comme du <b>texte</b> par Thymeleaf ({@code th:text}), qui echappe
     * le HTML -- un motif contenant des chevrons ne peut donc pas injecter de
     * balise dans le message.
     */
    @Async("mailExecutor")
    public void sendCoachRejected(String to, String fullName, String reason) {
        try {
            Context context = new Context();
            context.setVariable("fullName", fullName);
            context.setVariable("reason", reason);
            send(to, "Votre dossier coach FitForge demande une correction",
                    templateEngine.process("email/coach-rejected", context));
            log.info("Email de correction de dossier coach envoye a {}", mask(to));
        } catch (Exception e) {
            log.error("Echec de l'envoi de l'email de correction coach a {} : {}",
                    mask(to), e.getMessage());
        }
    }

    /**
     * Fabrique et expedie un message HTML. Extrait des methodes ci-dessus :
     * l'assemblage MIME, l'encodage et l'expediteur sont identiques pour tous
     * les emails du projet, et une divergence sur l'un d'eux (un charset oublie,
     * un expediteur absent) ne se voit qu'a la reception.
     */
    private void send(String to, String subject, String html) throws Exception {
        MimeMessage message = mailSender.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(
                message, MimeMessageHelper.MULTIPART_MODE_NO, StandardCharsets.UTF_8.name());
        helper.setTo(to);
        helper.setSubject(subject);
        helper.setText(html, true);
        if (fromAddress != null && !fromAddress.isBlank()) {
            helper.setFrom(fromAddress, fromName);
        }
        mailSender.send(message);
    }

    /**
     * Masque partiellement une adresse pour les logs
     * ({@code sami@fitforge.tn} -> {@code sa***@fitforge.tn}).
     */
    private String mask(String email) {
        if (email == null) return "?";
        int at = email.indexOf('@');
        if (at <= 2) return "***" + (at >= 0 ? email.substring(at) : "");
        return email.substring(0, 2) + "***" + email.substring(at);
    }
}
