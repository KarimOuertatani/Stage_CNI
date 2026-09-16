import type {
  CoachStatus,
  ProblemCategory,
  ProblemStatus,
  Role,
  CoachDocumentType,
} from "./types";
import type { Tone } from "@/components/ui";

/**
 * Traductions et mises en forme.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Une constante d'enumeration ne s'affiche jamais telle quelle
 * ═══════════════════════════════════════════════════════════════════
 * `PENDING`, `IDENTITY`, `MEAL_VOICE` sont des identifiants de code. Les
 * laisser passer a l'ecran donne une interface qui parle la langue de sa
 * base de donnees — et, ici, une console francaise parsemee d'anglais en
 * majuscules.
 *
 * La couleur est definie AU MEME ENDROIT que le libelle, volontairement :
 * separees, elles divergent. Un statut ajoute plus tard obtiendrait son
 * texte francais mais garderait la couleur neutre, et l'ecart ne se
 * verrait que sur un cas rare.
 */

// ── Statut d'une candidature coach ─────────────────────────────────

/**
 * ⚠️ « Valide » (vert) et « A corriger » (rouge) ne sont separes que de
 * dE 7,7 en deuteranopie — le couple rouge/vert classique. C'est
 * acceptable ICI, et seulement parce que ces etats ne sont JAMAIS rendus
 * par la couleur seule : ils passent toujours par un <Badge> qui porte
 * son libelle. Le texte est l'encodage principal, la couleur ne fait que
 * le renforcer.
 *
 * Consequence a tenir : ne jamais afficher un statut coach avec un simple
 * point colore sans libelle a cote.
 */
export const COACH_STATUS: Record<CoachStatus, { label: string; tone: Tone; hint: string }> = {
  DRAFT: {
    label: "Brouillon",
    tone: "neutral",
    hint: "Le coach constitue encore son dossier. Rien a examiner.",
  },
  PENDING: {
    label: "En attente",
    tone: "warn",
    hint: "Dossier soumis : il attend ta decision.",
  },
  APPROVED: {
    label: "Valide",
    tone: "ok",
    hint: "Le coach apparait dans l'annuaire et peut recevoir des adherents.",
  },
  REJECTED: {
    label: "A corriger",
    tone: "danger",
    hint: "Refuse avec un motif. Le coach peut corriger et renvoyer son dossier.",
  },
  SUSPENDED: {
    label: "Suspendu",
    tone: "danger",
    hint: "Retire de l'annuaire apres validation. Ses suivis en cours sont conserves.",
  },
};

// ── Type de justificatif ───────────────────────────────────────────

export const DOCUMENT_TYPE: Record<CoachDocumentType, { label: string; icon: string }> = {
  IDENTITY: { label: "Piece d'identite", icon: "🪪" },
  DIPLOMA: { label: "Diplome", icon: "🎓" },
  CERTIFICATION: { label: "Certification", icon: "📜" },
  OTHER: { label: "Autre justificatif", icon: "📎" },
};

// ── Role ───────────────────────────────────────────────────────────

export const ROLE: Record<Role, { label: string; tone: Tone }> = {
  ADHERENT: { label: "Adherent", tone: "info" },
  COACH: { label: "Coach", tone: "violet" },
  ADMIN: { label: "Admin", tone: "ok" },
};

// ── Signalements ───────────────────────────────────────────────────

/**
 * « En cours » est VIOLET et non cyan, et c'est une correction mesuree.
 *
 * Cyan (#00e5ff) et vert (#22d39a) ne sont separes que de dE 13,7 en
 * vision normale — sous le plancher de 15 en-deca duquel deux teintes
 * deviennent difficiles a distinguer meme sans trouble de la vision. Or
 * ces deux statuts se cotoient dans la MEME colonne d'un tableau de
 * signalements. En violet, la separation passe a dE 40,7.
 *
 * (Mesure : `scripts/validate_palette.js` de la reference dataviz, sur la
 * surface #0f1428. La couleur ne s'estime pas a l'oeil, elle se calcule.)
 */
export const PROBLEM_STATUS: Record<ProblemStatus, { label: string; tone: Tone }> = {
  NEW: { label: "Nouveau", tone: "warn" },
  IN_PROGRESS: { label: "En cours", tone: "violet" },
  RESOLVED: { label: "Resolu", tone: "ok" },
  CLOSED: { label: "Clos", tone: "neutral" },
};

export const PROBLEM_CATEGORY: Record<ProblemCategory, { label: string; icon: string }> = {
  BUG: { label: "Bug", icon: "🐞" },
  ACCOUNT: { label: "Compte", icon: "🔐" },
  CONTENT: { label: "Contenu errone", icon: "📊" },
  ABUSE: { label: "Comportement", icon: "⚠️" },
  SUGGESTION: { label: "Suggestion", icon: "💡" },
  OTHER: { label: "Autre", icon: "💬" },
};

// ── Dates ──────────────────────────────────────────────────────────

const DATE_TIME = new Intl.DateTimeFormat("fr-FR", {
  day: "2-digit",
  month: "short",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
});

const DATE_ONLY = new Intl.DateTimeFormat("fr-FR", {
  day: "2-digit",
  month: "short",
  year: "numeric",
});

export function formatDateTime(iso: string | null | undefined): string {
  if (!iso) return "—";
  return DATE_TIME.format(new Date(iso));
}

export function formatDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  return DATE_ONLY.format(new Date(iso));
}

/**
 * Anciennete en clair : « il y a 3 jours ».
 *
 * Sur une file d'attente, c'est plus utile qu'une date. « 12 fev. » oblige
 * a calculer de tete depuis combien de temps quelqu'un attend ; « il y a
 * 6 jours » repond directement a la question qu'on se pose en regardant
 * une file de moderation.
 */
export function timeAgo(iso: string | null | undefined): string {
  if (!iso) return "—";
  const diffMs = Date.now() - new Date(iso).getTime();
  const minutes = Math.floor(diffMs / 60000);

  if (minutes < 1) return "a l'instant";
  if (minutes < 60) return `il y a ${minutes} min`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `il y a ${hours} h`;

  const days = Math.floor(hours / 24);
  if (days === 1) return "hier";
  if (days < 30) return `il y a ${days} jours`;

  const months = Math.floor(days / 30);
  if (months < 12) return `il y a ${months} mois`;
  return `il y a ${Math.floor(months / 12)} an(s)`;
}

// ── Nombres ────────────────────────────────────────────────────────

const NUMBER = new Intl.NumberFormat("fr-FR");

export function formatNumber(value: number | null | undefined): string {
  if (value === null || value === undefined) return "—";
  return NUMBER.format(value);
}

export function formatBytes(bytes: number | null | undefined): string {
  if (!bytes) return "—";
  if (bytes < 1024) return `${bytes} o`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} Ko`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} Mo`;
}

/** Latence lisible : au-dela de la seconde, les millisecondes sont du bruit. */
export function formatLatency(ms: number | null | undefined): string {
  if (ms === null || ms === undefined) return "—";
  if (ms < 1000) return `${ms} ms`;
  return `${(ms / 1000).toFixed(1)} s`;
}

/**
 * Couleur d'un taux d'echec.
 *
 * Les seuils ne sont pas arbitraires : Gemini repond 503 de facon
 * reguliere sur les modeles les plus sollicites, et les clients du projet
 * reessaient deja trois fois. Quelques pourcents d'echec sont donc le
 * regime NORMAL de ce service — alerter des 1 % apprendrait a
 * l'administrateur a ignorer la couleur.
 */
export function failureTone(rate: number): Tone {
  if (rate >= 25) return "danger";
  if (rate >= 8) return "warn";
  return "ok";
}
