package com.fitforge.api.admin.service;

import com.fitforge.api.admin.entity.AiCallLog;
import com.fitforge.api.admin.repository.AiCallLogRepository;
import com.fitforge.api.common.enums.AiFeature;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Ecrit une ligne de journal d'appel IA, dans une transaction independante.
 *
 * <h2>Pourquoi cette classe existe separement de {@link AiCallRecorder}</h2>
 * Uniquement pour que {@code REQUIRES_NEW} soit reellement applique.
 *
 * <p>Spring implemente {@code @Transactional} par un <b>proxy</b> : un appel
 * d'une methode de la classe vers une autre methode de la meme classe ne
 * traverse pas ce proxy. Si cette methode vivait dans {@code AiCallRecorder} et
 * y etait appelee depuis {@code measure}, l'annotation serait <b>silencieusement
 * ignoree</b> -- le pire cas possible, puisque le code aurait l'air correct et
 * que le defaut ne se manifesterait qu'a l'annulation d'une transaction
 * appelante, en emportant la trace avec elle.
 *
 * <p>La transaction independante est necessaire pour une raison precise : la
 * generation de programme appelle Gemini <b>hors transaction</b>, mais d'autres
 * fonctions IA sont invoquees depuis un contexte transactionnel. Une trace
 * d'echec ecrite dans la transaction appelante serait annulee en meme temps que
 * l'echec qu'elle documente -- et la page de supervision n'afficherait jamais
 * les pannes, c'est-a-dire exactement ce pour quoi elle a ete construite.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AiCallLogWriter {

    private final AiCallLogRepository repository;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void write(AiFeature feature, boolean success, long latencyMs, String errorType) {
        try {
            repository.save(AiCallLog.builder()
                    .feature(feature)
                    .success(success)
                    .latencyMs(latencyMs)
                    .errorType(errorType)
                    .build());
        } catch (Exception e) {
            log.warn("Trace d'appel IA non enregistree ({}) : {}", feature, e.getMessage());
        }
    }
}
