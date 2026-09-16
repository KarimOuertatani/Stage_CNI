"use client";

import { useActionState, useState } from "react";
import { useFormStatus } from "react-dom";
import {
  approveCoach,
  rejectCoach,
  suspendCoach,
  type ActionState,
} from "@/app/(console)/coachs/actions";
import type { CoachStatus } from "@/lib/types";

/**
 * Panneau de decision d'un dossier de coach.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Approuver et refuser ne sont pas symetriques
 * ═══════════════════════════════════════════════════════════════════
 * Approuver demande une confirmation simple : la decision est
 * favorable, il n'y a rien a rediger.
 *
 * Refuser oblige a ECRIRE. Le champ de motif n'est pas un ornement de
 * formulaire — son contenu part tel quel dans l'email du coach et
 * s'affiche dans son application. C'est la seule chose qui lui permettra
 * de corriger. Un refus sans motif exploitable produit un dossier
 * resoumis a l'identique, donc le meme travail une seconde fois.
 *
 * D'ou les suggestions cliquables : elles ECRIVENT dans le champ au lieu
 * d'etre des cases a cocher. Un motif reel comporte presque toujours une
 * nuance qu'aucune liste ne capture, mais partir d'une phrase toute faite
 * evite la page blanche. (Meme choix que les suggestions de contraintes
 * de l'assistant de programme, cote mobile.)
 */

const REJECTION_SUGGESTIONS = [
  "La photo de ta piece d'identite est illisible : cadre les quatre coins, a plat et en pleine lumiere.",
  "Le nom porte par tes diplomes ne correspond pas a celui de ton compte.",
  "Il manque le justificatif correspondant a la certification que tu declares.",
  "Le document envoye est trop flou pour etre verifie.",
];

function SubmitButton({
  label,
  pendingLabel,
  variant,
}: {
  label: string;
  pendingLabel: string;
  variant: "approve" | "danger";
}) {
  const { pending } = useFormStatus();

  return (
    <button
      type="submit"
      disabled={pending}
      className={`depth w-full rounded-xl px-4 py-2.5 text-sm font-semibold transition-transform disabled:opacity-60 not-disabled:active:scale-[0.985] ${
        variant === "approve"
          ? "text-ground"
          : "border border-danger/40 bg-danger/12 text-danger hover:bg-danger/18"
      }`}
      style={
        variant === "approve"
          ? { background: "linear-gradient(135deg, var(--color-ok), #6ee7c0)" }
          : undefined
      }
    >
      {pending ? pendingLabel : label}
    </button>
  );
}

function Feedback({ state }: { state: ActionState }) {
  if (state.error) {
    return (
      <p
        role="alert"
        className="rounded-xl border border-danger/30 bg-danger/8 px-3.5 py-2.5 text-sm text-danger"
      >
        {state.error}
      </p>
    );
  }
  if (state.success) {
    return (
      <p
        role="status"
        className="rounded-xl border border-ok/30 bg-ok/8 px-3.5 py-2.5 text-sm text-ok"
      >
        {state.success}
      </p>
    );
  }
  return null;
}

export function ReviewPanel({
  profileId,
  status,
  coachName,
}: {
  profileId: string;
  status: CoachStatus;
  coachName: string;
}) {
  const [approveState, approveAction] = useActionState(
    approveCoach.bind(null, profileId),
    {} as ActionState,
  );
  const [rejectState, rejectAction] = useActionState(
    rejectCoach.bind(null, profileId),
    {} as ActionState,
  );
  const [suspendState, suspendAction] = useActionState(
    suspendCoach.bind(null, profileId),
    {} as ActionState,
  );

  const [reason, setReason] = useState("");
  const [mode, setMode] = useState<"none" | "reject" | "suspend">("none");

  // ── Etats sans decision possible ─────────────────────────────
  if (status === "DRAFT") {
    return (
      <div className="rounded-2xl border border-line bg-surface-2 px-5 py-6 text-center">
        <p className="text-2xl">✏️</p>
        <p className="mt-2 text-sm font-medium">Dossier non soumis</p>
        <p className="mt-1 text-sm text-ink-faint">
          {coachName} constitue encore son dossier. Il n&apos;y a rien a valider tant
          qu&apos;il ne l&apos;a pas envoye — ses justificatifs peuvent encore changer.
        </p>
      </div>
    );
  }

  if (status === "REJECTED") {
    return (
      <div className="rounded-2xl border border-line bg-surface-2 px-5 py-6 text-center">
        <p className="text-2xl">📝</p>
        <p className="mt-2 text-sm font-medium">En attente de correction</p>
        <p className="mt-1 text-sm text-ink-faint">
          Le motif a ete envoye. La balle est dans le camp du coach : il corrigera et
          renverra son dossier, qui reviendra alors dans la file.
        </p>
      </div>
    );
  }

  // ── Coach valide : seule la suspension reste ─────────────────
  if (status === "APPROVED") {
    return (
      <div className="flex flex-col gap-3">
        <Feedback state={suspendState} />

        {mode !== "suspend" ? (
          <button
            type="button"
            onClick={() => setMode("suspend")}
            className="w-full rounded-xl border border-line px-4 py-2.5 text-sm font-medium text-ink-muted transition-colors hover:border-danger/40 hover:text-danger"
          >
            Suspendre ce coach
          </button>
        ) : (
          <form action={suspendAction} className="flex flex-col gap-3">
            <p className="text-sm text-ink-muted">
              La suspension le retire de l&apos;annuaire et bloque les nouvelles demandes.
              <strong className="text-ink"> Ses suivis en cours et ses conversations sont conserves.</strong>
            </p>
            <textarea
              name="reason"
              rows={3}
              required
              minLength={10}
              placeholder="Motif de la suspension (conserve pour la tracabilite)"
              className="w-full resize-y rounded-xl border border-line bg-surface-2 px-3.5 py-2.5 text-sm outline-none placeholder:text-ink-faint/70 focus:border-danger/50"
            />
            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => setMode("none")}
                className="rounded-xl border border-line px-4 py-2.5 text-sm text-ink-muted transition-colors hover:text-ink"
              >
                Annuler
              </button>
              <div className="flex-1">
                <SubmitButton
                  label="Confirmer la suspension"
                  pendingLabel="Suspension…"
                  variant="danger"
                />
              </div>
            </div>
          </form>
        )}
      </div>
    );
  }

  if (status === "SUSPENDED") {
    return (
      <div className="flex flex-col gap-3">
        <Feedback state={approveState} />
        <p className="text-sm text-ink-muted">
          Ce coach est suspendu. Le revalider le remet dans l&apos;annuaire et lui renvoie
          l&apos;email d&apos;activation.
        </p>
        <form action={approveAction}>
          <SubmitButton
            label="Lever la suspension"
            pendingLabel="Validation…"
            variant="approve"
          />
        </form>
      </div>
    );
  }

  // ── PENDING : la decision a prendre ──────────────────────────
  return (
    <div className="flex flex-col gap-4">
      <Feedback state={approveState} />
      <Feedback state={rejectState} />

      {mode !== "reject" ? (
        <>
          <form action={approveAction}>
            <SubmitButton
              label="✓ Valider ce dossier"
              pendingLabel="Validation…"
              variant="approve"
            />
          </form>
          <p className="-mt-1 text-xs text-ink-faint">
            {coachName} entrera dans l&apos;annuaire et recevra un email d&apos;activation.
          </p>

          <div className="h-px bg-line" />

          <button
            type="button"
            onClick={() => setMode("reject")}
            className="w-full rounded-xl border border-line px-4 py-2.5 text-sm font-medium text-ink-muted transition-colors hover:border-danger/40 hover:text-danger"
          >
            Demander une correction
          </button>
        </>
      ) : (
        <form action={rejectAction} className="flex flex-col gap-3">
          <div>
            <label htmlFor="reason" className="mb-1.5 block text-sm font-medium">
              Qu&apos;est-ce qui doit etre corrige ?
            </label>
            <p className="mb-2 text-xs text-ink-faint">
              Ce texte part <strong className="text-ink-muted">tel quel</strong> dans
              l&apos;email de {coachName} et s&apos;affiche dans son application. C&apos;est
              la seule chose qui lui dira quoi refaire.
            </p>
            <textarea
              id="reason"
              name="reason"
              rows={4}
              required
              minLength={10}
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="Explique precisement ce qui bloque…"
              className="w-full resize-y rounded-xl border border-line bg-surface-2 px-3.5 py-2.5 text-sm outline-none placeholder:text-ink-faint/70 focus:border-warn/50"
            />
          </div>

          {/* Suggestions : elles ECRIVENT dans le champ, elles ne le
              remplacent pas par une case a cocher. */}
          <div className="flex flex-wrap gap-1.5">
            {REJECTION_SUGGESTIONS.map((text) => (
              <button
                key={text}
                type="button"
                onClick={() => setReason(text)}
                className="rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-left text-xs text-ink-muted transition-colors hover:border-white/25 hover:text-ink"
              >
                {text.length > 52 ? `${text.slice(0, 52)}…` : text}
              </button>
            ))}
          </div>

          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => setMode("none")}
              className="rounded-xl border border-line px-4 py-2.5 text-sm text-ink-muted transition-colors hover:text-ink"
            >
              Annuler
            </button>
            <div className="flex-1">
              <SubmitButton
                label="Envoyer la demande de correction"
                pendingLabel="Envoi…"
                variant="danger"
              />
            </div>
          </div>
        </form>
      )}
    </div>
  );
}
