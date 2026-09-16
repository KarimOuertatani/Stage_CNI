"use client";

import { useActionState, useState } from "react";
import { useFormStatus } from "react-dom";
import { handleReport, type ActionState } from "@/app/(console)/signalements/actions";
import { PROBLEM_STATUS } from "@/lib/format";
import type { ProblemStatus } from "@/lib/types";

/**
 * Formulaire de traitement d'un signalement.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Le champ de reponse apparait quand il devient obligatoire
 * ═══════════════════════════════════════════════════════════════════
 * Choisir « Resolu » ou « Clos » fait apparaitre une consigne explicite :
 * ce texte sera lu par l'auteur. Choisir « En cours » ne l'exige pas.
 *
 * Cette dependance entre le statut choisi et l'obligation d'ecrire est
 * montree AVANT la soumission plutot qu'apres : un formulaire qui accepte
 * puis refuse fait perdre deux fois plus de temps qu'un formulaire qui
 * previent.
 */

const CHOICES: ProblemStatus[] = ["IN_PROGRESS", "RESOLVED", "CLOSED"];
const CLOSING: ProblemStatus[] = ["RESOLVED", "CLOSED"];

function SubmitButton({ closing }: { closing: boolean }) {
  const { pending } = useFormStatus();

  return (
    <button
      type="submit"
      disabled={pending}
      className="depth w-full rounded-xl px-4 py-2.5 text-sm font-semibold text-white transition-transform disabled:opacity-60 not-disabled:active:scale-[0.985]"
      style={{
        background: "linear-gradient(135deg, var(--color-violet), var(--color-cyan))",
      }}
    >
      {pending ? "Enregistrement…" : closing ? "Repondre et cloturer" : "Enregistrer"}
    </button>
  );
}

export function ReportHandler({
  reportId,
  currentStatus,
  currentResponse,
  reporterName,
}: {
  reportId: string;
  currentStatus: ProblemStatus;
  currentResponse: string | null;
  reporterName: string;
}) {
  const [state, action] = useActionState(
    handleReport.bind(null, reportId),
    {} as ActionState,
  );

  // Preselection : « Nouveau » propose la premiere etape utile plutot que
  // de laisser choisir dans le vide.
  const [status, setStatus] = useState<ProblemStatus>(
    currentStatus === "NEW" ? "IN_PROGRESS" : currentStatus,
  );
  const closing = CLOSING.includes(status);

  return (
    <form action={action} className="flex flex-col gap-4">
      {state.error && (
        <p
          role="alert"
          className="rounded-xl border border-danger/30 bg-danger/8 px-3.5 py-2.5 text-sm text-danger"
        >
          {state.error}
        </p>
      )}
      {state.success && (
        <p
          role="status"
          className="rounded-xl border border-ok/30 bg-ok/8 px-3.5 py-2.5 text-sm text-ok"
        >
          {state.success}
        </p>
      )}

      {/* ── Statut ─────────────────────────────────────────────── */}
      <fieldset>
        <legend className="mb-2 text-sm font-medium">Nouveau statut</legend>
        <input type="hidden" name="status" value={status} />

        <div className="flex flex-col gap-2">
          {CHOICES.map((choice) => {
            const meta = PROBLEM_STATUS[choice];
            const selected = status === choice;

            return (
              <button
                key={choice}
                type="button"
                onClick={() => setStatus(choice)}
                aria-pressed={selected}
                className={`flex items-start gap-3 rounded-xl border px-3.5 py-2.5 text-left transition-colors ${
                  selected
                    ? "border-violet/50 bg-violet/10"
                    : "border-line hover:border-white/20"
                }`}
              >
                <span
                  className={`mt-0.5 grid size-4 shrink-0 place-items-center rounded-full border ${
                    selected ? "border-violet" : "border-line"
                  }`}
                >
                  {selected && <span className="size-2 rounded-full bg-violet" />}
                </span>
                <span className="min-w-0">
                  <span className="block text-sm font-medium">{meta.label}</span>
                  <span className="block text-xs text-ink-faint">
                    {choice === "IN_PROGRESS" && "Quelqu'un s'en occupe. Aucune reponse exigee."}
                    {choice === "RESOLVED" && "Le probleme est corrige ou la demande satisfaite."}
                    {choice === "CLOSED" && "Rien a faire : doublon, hors perimetre, ou comportement normal."}
                  </span>
                </span>
              </button>
            );
          })}
        </div>
      </fieldset>

      {/* ── Reponse ────────────────────────────────────────────── */}
      <div>
        <label htmlFor="response" className="mb-1.5 block text-sm font-medium">
          Reponse a {reporterName}
          {closing && <span className="ml-1.5 text-xs font-normal text-warn">obligatoire</span>}
        </label>
        <p className="mb-2 text-xs text-ink-faint">
          {closing
            ? "Elle s'affichera sous le statut, dans son ecran « Mes signalements ». C'est la seule chose qui lui dira ce qui a ete fait."
            : "Facultative a cette etape. Tu pourras l'ecrire au moment de cloturer."}
        </p>
        <textarea
          id="response"
          name="response"
          rows={4}
          defaultValue={currentResponse ?? ""}
          required={closing}
          placeholder={
            closing
              ? "Corrige dans la prochaine version : le minuteur repart bien apres une pause."
              : "Note interne ou premiere reponse…"
          }
          className="w-full resize-y rounded-xl border border-line bg-surface-2 px-3.5 py-2.5 text-sm outline-none placeholder:text-ink-faint/70 focus:border-violet/60"
        />
      </div>

      <SubmitButton closing={closing} />
    </form>
  );
}
