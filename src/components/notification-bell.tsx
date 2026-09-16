"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

/**
 * Cloche des notifications.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Consultation periodique, pas de temps reel — et c'est reflechi
 * ═══════════════════════════════════════════════════════════════════
 * Le projet dispose deja d'une infrastructure WebSocket/STOMP (le chat
 * coach-adherent), et y brancher un canal d'administration etait possible.
 * Ce n'est pas fait :
 *
 *  - le besoin n'est pas temps reel : une candidature attend de toute
 *    facon des heures avant d'etre examinee ;
 *  - un second client STOMP, dans une autre pile technique, avec sa
 *    reconnexion et son authentification propres, est une surface entiere
 *    a maintenir pour ce gain nul ;
 *  - SSE n'aiderait pas : `EventSource` n'accepte pas d'en-tete
 *    `Authorization`, il faudrait passer le jeton en parametre d'URL —
 *    donc l'ecrire dans les journaux d'acces.
 *
 * L'intervalle de 60 s est un compromis assume : assez court pour qu'un
 * administrateur remarque une arrivee pendant qu'il travaille, assez long
 * pour rester negligeable (une requete qui se resout sur un index
 * partiel).
 */

const POLL_INTERVAL_MS = 60_000;

export function NotificationBell({ initialCount }: { initialCount: number }) {
  const [count, setCount] = useState(initialCount);

  useEffect(() => {
    // `AbortController` : sans lui, une reponse arrivant apres le demontage
    // du composant provoquerait une mise a jour d'etat dans le vide.
    const controller = new AbortController();

    async function refresh() {
      // Inutile d'interroger le serveur pour un onglet en arriere-plan :
      // personne ne regarde, et une console laissee ouverte la nuit
      // enverrait des centaines de requetes pour rien.
      if (document.visibilityState !== "visible") return;

      try {
        const res = await fetch("/api/notifications/count", {
          signal: controller.signal,
          cache: "no-store",
        });
        if (!res.ok) return;
        const body = await res.json();
        if (typeof body.count === "number") setCount(body.count);
      } catch {
        // Reseau coupe ou requete annulee : on garde la derniere valeur
        // connue plutot que d'afficher zero, qui serait un mensonge.
      }
    }

    const timer = setInterval(refresh, POLL_INTERVAL_MS);
    document.addEventListener("visibilitychange", refresh);

    return () => {
      controller.abort();
      clearInterval(timer);
      document.removeEventListener("visibilitychange", refresh);
    };
  }, []);

  return (
    <Link
      href="/notifications"
      className="relative grid size-10 place-items-center rounded-xl border border-line bg-surface text-lg transition-colors hover:border-white/20"
      aria-label={
        count > 0 ? `Notifications, ${count} non lues` : "Notifications, aucune non lue"
      }
    >
      🔔
      {count > 0 && (
        <span
          className="absolute -top-1.5 -right-1.5 grid min-w-5 place-items-center rounded-full px-1.5 py-0.5 text-[0.65rem] font-bold text-white tabular-nums"
          style={{ background: "var(--color-danger)" }}
        >
          {count > 99 ? "99+" : count}
        </span>
      )}
    </Link>
  );
}
