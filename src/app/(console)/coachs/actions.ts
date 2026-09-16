"use server";

import { revalidatePath } from "next/cache";
import { apiFetch, ApiError } from "@/lib/api";

/**
 * Decisions sur une candidature de coach.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Ces trois actions ont des consequences reelles et immediates
 * ═══════════════════════════════════════════════════════════════════
 * Approuver fait entrer un coach dans l'annuaire et lui envoie un email.
 * Refuser lui en envoie un autre, avec le motif ecrit ici, tel quel.
 * Suspendre retire de l'annuaire un coach qui a des adherents en suivi.
 *
 * Aucune n'est annulable par un « retour arriere » : l'email est parti.
 * C'est pourquoi l'interface demande confirmation, et pourquoi le motif
 * est obligatoire cote serveur — le backend refuse un motif de moins de
 * dix caracteres, et ce refus est remonte tel quel a l'ecran plutot que
 * traduit, parce qu'il est deja redige pour etre lu.
 */

export interface ActionState {
  error?: string;
  success?: string;
}

/**
 * Rafraichit les vues touchees par une decision.
 *
 * Trois chemins, pas un seul : la fiche (qui affiche le nouveau statut),
 * la liste (d'ou le dossier doit disparaitre s'il etait filtre sur « en
 * attente »), et le tableau de bord (dont la tuile doit decrementer).
 * Oublier le dernier laisserait un compteur perime sur la page d'accueil
 * — le genre d'incoherence qui fait douter de tout le reste.
 */
function revalidateAll(profileId: string) {
  revalidatePath(`/coachs/${profileId}`);
  revalidatePath("/coachs");
  revalidatePath("/");
}

function toMessage(error: unknown): string {
  if (error instanceof ApiError) return error.message;
  return "Le serveur n'a pas repondu. Reessaie dans un instant.";
}

export async function approveCoach(
  profileId: string,
  _prev: ActionState,
  _formData: FormData,
): Promise<ActionState> {
  try {
    await apiFetch(`/admin/coach-applications/${profileId}/approve`, { method: "POST" });
    revalidateAll(profileId);
    return { success: "Dossier valide. Le coach a recu l'email d'activation." };
  } catch (error) {
    return { error: toMessage(error) };
  }
}

export async function rejectCoach(
  profileId: string,
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const reason = String(formData.get("reason") ?? "").trim();

  // Controle cote client AUSSI, en plus du backend : faire l'aller-retour
  // pour apprendre qu'on a oublie le motif est une friction inutile.
  // Le backend reste la seule autorite — celui-ci n'est qu'une courtoisie.
  if (reason.length < 10) {
    return { error: "Ecris un motif d'au moins 10 caracteres : le coach le recevra tel quel." };
  }

  try {
    await apiFetch(`/admin/coach-applications/${profileId}/reject`, {
      method: "POST",
      body: { reason },
    });
    revalidateAll(profileId);
    return { success: "Dossier refuse. Le coach a recu le motif et peut le corriger." };
  } catch (error) {
    return { error: toMessage(error) };
  }
}

export async function suspendCoach(
  profileId: string,
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const reason = String(formData.get("reason") ?? "").trim();

  if (reason.length < 10) {
    return { error: "Ecris un motif d'au moins 10 caracteres." };
  }

  try {
    await apiFetch(`/admin/coach-applications/${profileId}/suspend`, {
      method: "POST",
      body: { reason },
    });
    revalidateAll(profileId);
    return { success: "Coach suspendu. Il ne recoit plus de nouvelles demandes." };
  } catch (error) {
    return { error: toMessage(error) };
  }
}
