"use server";

import { revalidatePath } from "next/cache";
import { apiFetch, ApiError } from "@/lib/api";
import type { ProblemStatus } from "@/lib/types";

export interface ActionState {
  error?: string;
  success?: string;
}

/**
 * Traitement d'un signalement.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Cloturer OBLIGE a repondre
 * ═══════════════════════════════════════════════════════════════════
 * Le backend refuse un passage en « Resolu » ou « Clos » sans texte, et
 * cette regle est reprise ici pour eviter un aller-retour inutile.
 *
 * La raison est la promesse faite a l'utilisateur : son ecran affichera
 * « Resolu » avec, juste en dessous, l'explication. Un statut sans texte
 * serait pire que pas de reponse — il annoncerait une correction sans
 * dire laquelle, tout en fermant le sujet.
 *
 * « En cours » n'exige rien : c'est deja une information en soi
 * (« quelqu'un s'en occupe »), et forcer un texte a cette etape ferait
 * ecrire « ok » pour satisfaire le formulaire.
 */

const CLOSING: ProblemStatus[] = ["RESOLVED", "CLOSED"];

export async function handleReport(
  reportId: string,
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const status = String(formData.get("status") ?? "") as ProblemStatus;
  const response = String(formData.get("response") ?? "").trim();

  if (!status) {
    return { error: "Choisis un statut." };
  }
  if (CLOSING.includes(status) && !response) {
    return {
      error: "Ecris une reponse : l'auteur du signalement la verra dans l'application.",
    };
  }

  try {
    await apiFetch(`/admin/problem-reports/${reportId}/handle`, {
      method: "POST",
      body: { status, response: response || null },
    });

    revalidatePath(`/signalements/${reportId}`);
    revalidatePath("/signalements");
    revalidatePath("/");

    return {
      success: CLOSING.includes(status)
        ? "Signalement cloture. L'auteur voit ta reponse dans l'application."
        : "Signalement pris en charge.",
    };
  } catch (error) {
    if (error instanceof ApiError) return { error: error.message };
    return { error: "Le serveur n'a pas repondu. Reessaie dans un instant." };
  }
}
