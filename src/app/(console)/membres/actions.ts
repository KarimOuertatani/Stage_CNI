"use server";

import { revalidatePath } from "next/cache";
import { apiFetch, ApiError } from "@/lib/api";

export interface ActionState {
  error?: string;
  success?: string;
}

/**
 * Suspension et reactivation d'un compte.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Il n'y a PAS d'action de suppression, et c'est deliberé
 * ═══════════════════════════════════════════════════════════════════
 * Le backend n'expose aucune route de suppression de compte. Effacer un
 * membre cascaderait sur ses seances, ses repas, ses nuits, ses messages
 * et ses relations de suivi — y compris cote coach, qui verrait un
 * adherent disparaitre de sa liste sans explication.
 *
 * Un geste irreversible de cette portee n'a pas sa place a cote d'un
 * bouton « suspendre » qui lui ressemble, dans une liste ou l'on clique
 * vite. Le jour ou une demande d'effacement devra etre honoree, elle
 * meritera sa propre procedure.
 */

function toMessage(error: unknown): string {
  if (error instanceof ApiError) return error.message;
  return "Le serveur n'a pas repondu. Reessaie dans un instant.";
}

function revalidateAll(userId: string) {
  revalidatePath(`/membres/${userId}`);
  revalidatePath("/membres");
  revalidatePath("/");
}

export async function suspendUser(
  userId: string,
  _prev: ActionState,
  _formData: FormData,
): Promise<ActionState> {
  try {
    await apiFetch(`/admin/users/${userId}/suspend`, { method: "POST" });
    revalidateAll(userId);
    return { success: "Compte suspendu. Il ne peut plus se connecter." };
  } catch (error) {
    return { error: toMessage(error) };
  }
}

export async function reactivateUser(
  userId: string,
  _prev: ActionState,
  _formData: FormData,
): Promise<ActionState> {
  try {
    await apiFetch(`/admin/users/${userId}/reactivate`, { method: "POST" });
    revalidateAll(userId);
    return { success: "Compte reactive." };
  } catch (error) {
    return { error: toMessage(error) };
  }
}
