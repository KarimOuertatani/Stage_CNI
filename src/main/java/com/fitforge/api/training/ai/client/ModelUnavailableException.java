package com.fitforge.api.training.ai.client;

import com.fitforge.api.common.exception.BusinessException;

/**
 * Le modele n'a rien traite : il etait injoignable ou sature.
 *
 * <h2>Pourquoi cet echec-la est different des autres</h2>
 *
 * <p>Toutes les generations ratees ne se valent pas. Une reponse illisible, un
 * programme inexploitable, une requete refusee : dans ces cas, le modele a
 * <b>travaille</b> — des jetons ont ete consommes, et le quota Gemini partage
 * avec le coach IA, l'analyse de photo et l'ajout vocal a bel et bien diminue.
 * Il est donc juste que la tentative compte dans le plafond de l'adherent.
 *
 * <p>Un 503, lui, veut dire que Gemini n'a <b>rien fait du tout</b>. Rien n'a
 * ete consomme. Faire compter cette tentative reviendrait a punir l'adherent
 * d'une panne qui n'est ni la sienne ni la notre — et le cas est loin d'etre
 * theorique : quelqu'un qui appuie cinq fois sur « Reessayer » pendant une
 * saturation se retrouverait bloque vingt-quatre heures <b>sans avoir obtenu un
 * seul programme</b>.
 *
 * <p>D'ou ce type dedie : il permet a {@code AiProgramService} de reconnaitre
 * ce cas precis et de ne pas debiter le quota. Distinguer par le texte du
 * message aurait marche jusqu'a la premiere reformulation.
 */
public class ModelUnavailableException extends BusinessException {

    public ModelUnavailableException(String message) {
        super(message);
    }
}
