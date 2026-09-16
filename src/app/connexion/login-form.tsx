"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { login, type LoginState } from "@/lib/auth";

/**
 * Formulaire de connexion.
 *
 * Il passe par une action serveur : les identifiants ne transitent jamais
 * par du JavaScript de page, et le jeton renvoye est pose directement dans
 * un cookie `httpOnly` cote serveur — le navigateur ne le voit jamais.
 */

/**
 * Bouton de soumission.
 *
 * Il est dans un composant a part parce que `useFormStatus` ne renvoie
 * l'etat du formulaire que depuis un ENFANT de celui-ci. Appele dans le
 * meme composant que `<form>`, il renverrait toujours `pending: false` —
 * et le bouton n'indiquerait jamais qu'il travaille.
 */
function SubmitButton() {
  const { pending } = useFormStatus();

  return (
    <button
      type="submit"
      disabled={pending}
      className="depth relative w-full overflow-hidden rounded-xl px-4 py-3 text-sm font-semibold text-white transition-transform disabled:opacity-70 not-disabled:active:scale-[0.985]"
      style={{
        background: "linear-gradient(135deg, var(--color-violet), var(--color-cyan))",
      }}
    >
      {pending ? "Connexion…" : "Se connecter"}
    </button>
  );
}

export function LoginForm() {
  const [state, formAction] = useActionState<LoginState, FormData>(login, {});

  return (
    <form action={formAction} className="flex flex-col gap-4">
      <div>
        <label htmlFor="email" className="mb-1.5 block text-xs font-medium text-ink-muted">
          Adresse email
        </label>
        <input
          id="email"
          name="email"
          type="email"
          required
          autoComplete="username"
          autoFocus
          placeholder="admin@fitforge.local"
          className="w-full rounded-xl border border-line bg-surface-2 px-3.5 py-2.5 text-sm outline-none transition-colors placeholder:text-ink-faint/70 focus:border-violet/60"
        />
      </div>

      <div>
        <label htmlFor="password" className="mb-1.5 block text-xs font-medium text-ink-muted">
          Mot de passe
        </label>
        <input
          id="password"
          name="password"
          type="password"
          required
          autoComplete="current-password"
          placeholder="••••••••"
          className="w-full rounded-xl border border-line bg-surface-2 px-3.5 py-2.5 text-sm outline-none transition-colors placeholder:text-ink-faint/70 focus:border-violet/60"
        />
      </div>

      {/*
        `role="alert"` : le message d'erreur apparait apres coup, sans que
        le focus bouge. Sans annonce, un lecteur d'ecran ne signalerait
        rien et l'utilisateur croirait que le bouton n'a pas repondu.
      */}
      {state.error && (
        <p
          role="alert"
          className="rounded-xl border border-danger/30 bg-danger/8 px-3.5 py-2.5 text-sm text-danger"
        >
          {state.error}
        </p>
      )}

      <SubmitButton />
    </form>
  );
}
