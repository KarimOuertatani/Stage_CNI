"use client";

import { useActionState, useState } from "react";
import { useFormStatus } from "react-dom";
import {
  reactivateUser,
  suspendUser,
  type ActionState,
} from "@/app/(console)/membres/actions";

/**
 * Suspension / reactivation d'un compte.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  La confirmation n'est pas une politesse
 * ═══════════════════════════════════════════════════════════════════
 * Suspendre coupe l'acces d'une personne reelle a ses donnees. Un bouton
 * qui agirait au premier clic, dans une fiche que l'on parcourt, ferait
 * tot ou tard une victime par erreur de visee.
 *
 * L'ecran de confirmation dit ce qui va se passer ET ce qui ne se passera
 * pas — « ses seances, repas et messages sont conserves ». Sans cette
 * seconde moitie, un administrateur hesite a suspendre un compte
 * litigieux de peur de detruire des donnees, et le probleme reste.
 */

function SubmitButton({
  label,
  pendingLabel,
  variant,
}: {
  label: string;
  pendingLabel: string;
  variant: "danger" | "ok";
}) {
  const { pending } = useFormStatus();

  return (
    <button
      type="submit"
      disabled={pending}
      className={`w-full rounded-xl border px-4 py-2.5 text-sm font-semibold transition-colors disabled:opacity-60 ${
        variant === "danger"
          ? "border-danger/40 bg-danger/12 text-danger hover:bg-danger/18"
          : "border-ok/40 bg-ok/12 text-ok hover:bg-ok/18"
      }`}
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

export function AccountActions({
  userId,
  enabled,
  emailVerified,
  isAdmin,
  name,
}: {
  userId: string;
  enabled: boolean;
  emailVerified: boolean;
  isAdmin: boolean;
  name: string;
}) {
  const [suspendState, suspendAction] = useActionState(
    suspendUser.bind(null, userId),
    {} as ActionState,
  );
  const [reactivateState, reactivateAction] = useActionState(
    reactivateUser.bind(null, userId),
    {} as ActionState,
  );
  const [confirming, setConfirming] = useState(false);

  if (isAdmin) {
    return (
      <p className="rounded-xl border border-line bg-surface-2 px-3.5 py-3 text-sm text-ink-faint">
        Un compte administrateur ne se gere pas depuis la console. Cette restriction
        evite qu&apos;une erreur de manipulation ferme l&apos;acces a
        l&apos;administration elle-meme.
      </p>
    );
  }

  // Compte inactif faute de verification d'email : ce n'est pas une
  // sanction, et le reactiver reviendrait a contourner la verification.
  if (!enabled && !emailVerified) {
    return (
      <div className="flex flex-col gap-3">
        <Feedback state={reactivateState} />
        <p className="rounded-xl border border-warn/30 bg-warn/8 px-3.5 py-3 text-sm text-warn">
          Ce compte n&apos;a jamais confirme son adresse email. Il n&apos;est pas
          suspendu : il est inachevé. {name} doit saisir le code a six chiffres recu a
          l&apos;inscription — la console ne peut pas le faire a sa place.
        </p>
      </div>
    );
  }

  if (!enabled) {
    return (
      <div className="flex flex-col gap-3">
        <Feedback state={reactivateState} />
        <p className="text-sm text-ink-muted">
          Ce compte est suspendu : {name} ne peut plus se connecter. Ses donnees sont
          intactes.
        </p>
        <form action={reactivateAction}>
          <SubmitButton label="Reactiver le compte" pendingLabel="Reactivation…" variant="ok" />
        </form>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      <Feedback state={suspendState} />

      {!confirming ? (
        <button
          type="button"
          onClick={() => setConfirming(true)}
          className="w-full rounded-xl border border-line px-4 py-2.5 text-sm font-medium text-ink-muted transition-colors hover:border-danger/40 hover:text-danger"
        >
          Suspendre ce compte
        </button>
      ) : (
        <form action={suspendAction} className="flex flex-col gap-3">
          <div className="rounded-xl border border-danger/30 bg-danger/8 px-3.5 py-3">
            <p className="text-sm font-medium text-danger">Suspendre {name} ?</p>
            <ul className="mt-2 flex flex-col gap-1 text-sm text-ink-muted">
              <li>· Il ne pourra plus se connecter.</li>
              <li>· Ses seances, repas, nuits et messages sont conserves.</li>
              <li>· L&apos;action est reversible a tout moment.</li>
            </ul>
            {/*
              Cette precision evite une mauvaise surprise : le projet est
              sans session serveur, un JWT deja emis reste valide jusqu'a
              son expiration. Le cacher ferait croire a une coupure
              immediate.
            */}
            <p className="mt-2 text-xs text-ink-faint">
              Une session deja ouverte peut rester active jusqu&apos;a 24 h (duree de
              validite du jeton).
            </p>
          </div>

          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => setConfirming(false)}
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
