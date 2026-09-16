"use client";

import { useEffect, useState } from "react";
import { documentUrl } from "@/lib/urls";
import { DOCUMENT_TYPE, formatBytes, formatDateTime } from "@/lib/format";
import type { CoachDocument } from "@/lib/types";
import { Badge } from "./ui";

/**
 * Galerie des justificatifs d'un dossier.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  L'examen se fait en GRAND, pas sur une vignette
 * ═══════════════════════════════════════════════════════════════════
 * Verifier qu'un nom sur un diplome correspond a celui du compte, ou
 * qu'une piece d'identite n'est pas un montage, demande de LIRE le
 * document. Une grille de vignettes de 150 px permet de constater qu'un
 * fichier existe, pas de l'examiner — et un administrateur presse
 * validerait sur la seule presence des pieces, ce qui reviendrait a
 * supprimer la verification tout en croyant l'avoir faite.
 *
 * D'ou la visionneuse plein ecran, avec zoom, ouverte au clic.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Les PDF ne sont pas des images
 * ═══════════════════════════════════════════════════════════════════
 * Un `<img>` sur un PDF affiche une icone de fichier casse. Les deux
 * types sont donc traites separement : `<img>` pour les images,
 * `<iframe>` pour les PDF (le lecteur integre du navigateur), et une
 * carte de repli pour tout le reste.
 */

/** Le backend n'accepte que ces types ; on s'aligne sur lui. */
function isImage(contentType: string | null): boolean {
  return !!contentType && contentType.startsWith("image/");
}

function isPdf(contentType: string | null): boolean {
  return contentType === "application/pdf";
}

export function DocumentGallery({ documents }: { documents: CoachDocument[] }) {
  const [openIndex, setOpenIndex] = useState<number | null>(null);

  // Fermeture au clavier. Une visionneuse plein ecran sans Echap piege
  // l'utilisateur : le premier reflexe est cette touche, pas la croix.
  useEffect(() => {
    if (openIndex === null) return;

    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") setOpenIndex(null);
      if (event.key === "ArrowRight") {
        setOpenIndex((i) => (i === null ? null : Math.min(i + 1, documents.length - 1)));
      }
      if (event.key === "ArrowLeft") {
        setOpenIndex((i) => (i === null ? null : Math.max(i - 1, 0)));
      }
    }

    window.addEventListener("keydown", onKey);
    // Le fond ne doit pas defiler derriere la visionneuse.
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = previous;
    };
  }, [openIndex, documents.length]);

  if (documents.length === 0) {
    return (
      <p className="rounded-xl border border-line bg-surface-2 px-4 py-6 text-center text-sm text-ink-faint">
        Aucun justificatif depose.
      </p>
    );
  }

  const open = openIndex !== null ? documents[openIndex] : null;

  return (
    <>
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {documents.map((doc, index) => {
          const meta = DOCUMENT_TYPE[doc.type];
          const url = documentUrl(doc.id);

          return (
            <button
              key={doc.id}
              type="button"
              onClick={() => setOpenIndex(index)}
              className="group edge-lit depth overflow-hidden rounded-xl border border-line bg-surface-2 text-left transition-colors hover:border-violet/50"
            >
              {/* Apercu */}
              <div className="relative grid h-40 place-items-center overflow-hidden bg-ground">
                {isImage(doc.contentType) ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={url}
                    alt=""
                    className="size-full object-cover transition-transform duration-300 group-hover:scale-[1.03]"
                  />
                ) : (
                  <div className="flex flex-col items-center gap-2 text-ink-faint">
                    <span className="text-3xl">{isPdf(doc.contentType) ? "📄" : meta.icon}</span>
                    <span className="text-xs">{isPdf(doc.contentType) ? "PDF" : "Fichier"}</span>
                  </div>
                )}

                <span className="absolute top-2 left-2">
                  <Badge tone={doc.type === "IDENTITY" ? "violet" : "neutral"}>
                    {meta.icon} {meta.label}
                  </Badge>
                </span>
              </div>

              {/* Legende */}
              <div className="p-3">
                <p className="truncate text-sm font-medium text-ink">
                  {doc.label ?? doc.originalName ?? meta.label}
                </p>
                <p className="mt-0.5 truncate text-xs text-ink-faint">
                  {formatBytes(doc.sizeBytes)} · {formatDateTime(doc.uploadedAt)}
                </p>
              </div>
            </button>
          );
        })}
      </div>

      {/* ══ Visionneuse ══════════════════════════════════════════ */}
      {open && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label={`Justificatif : ${open.label ?? DOCUMENT_TYPE[open.type].label}`}
          className="fixed inset-0 z-50 flex flex-col bg-ground/95 backdrop-blur-sm"
          onClick={() => setOpenIndex(null)}
        >
          {/* Barre de titre */}
          <div
            className="flex shrink-0 items-center gap-4 border-b border-line px-5 py-3"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-semibold">
                {open.label ?? open.originalName ?? DOCUMENT_TYPE[open.type].label}
              </p>
              <p className="truncate text-xs text-ink-faint">
                {DOCUMENT_TYPE[open.type].label} · {formatBytes(open.sizeBytes)}
              </p>
            </div>

            <span className="shrink-0 text-xs text-ink-faint tabular-nums">
              {(openIndex ?? 0) + 1} / {documents.length}
            </span>

            <a
              href={documentUrl(open.id)}
              target="_blank"
              rel="noreferrer"
              className="shrink-0 rounded-lg border border-line px-3 py-1.5 text-xs text-ink-muted transition-colors hover:border-white/25 hover:text-ink"
            >
              Ouvrir dans un onglet
            </a>

            <button
              type="button"
              onClick={() => setOpenIndex(null)}
              aria-label="Fermer"
              className="grid size-8 shrink-0 place-items-center rounded-lg border border-line text-ink-muted transition-colors hover:border-white/25 hover:text-ink"
            >
              ✕
            </button>
          </div>

          {/* Contenu */}
          <div
            className="flex min-h-0 flex-1 items-center justify-center p-4"
            onClick={(e) => e.stopPropagation()}
          >
            {isImage(open.contentType) ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={documentUrl(open.id)}
                alt=""
                className="max-h-full max-w-full rounded-lg object-contain"
              />
            ) : isPdf(open.contentType) ? (
              <iframe
                src={documentUrl(open.id)}
                title="Justificatif"
                className="size-full rounded-lg border border-line bg-white"
              />
            ) : (
              <div className="text-center text-ink-muted">
                <p className="mb-3 text-4xl">📎</p>
                <p className="text-sm">Ce format ne peut pas etre affiche ici.</p>
                <a
                  href={documentUrl(open.id)}
                  target="_blank"
                  rel="noreferrer"
                  className="mt-3 inline-block text-sm text-cyan underline"
                >
                  Ouvrir le fichier
                </a>
              </div>
            )}
          </div>

          {/* Navigation entre pieces : examiner un dossier, c'est passer de
              l'une a l'autre, pas fermer et rouvrir a chaque fois. */}
          {documents.length > 1 && (
            <div
              className="flex shrink-0 items-center justify-center gap-3 border-t border-line px-5 py-3"
              onClick={(e) => e.stopPropagation()}
            >
              <button
                type="button"
                disabled={openIndex === 0}
                onClick={() => setOpenIndex((i) => Math.max((i ?? 0) - 1, 0))}
                className="rounded-lg border border-line px-4 py-1.5 text-xs text-ink-muted transition-colors not-disabled:hover:text-ink disabled:opacity-35"
              >
                ← Precedent
              </button>
              <button
                type="button"
                disabled={openIndex === documents.length - 1}
                onClick={() =>
                  setOpenIndex((i) => Math.min((i ?? 0) + 1, documents.length - 1))
                }
                className="rounded-lg border border-line px-4 py-1.5 text-xs text-ink-muted transition-colors not-disabled:hover:text-ink disabled:opacity-35"
              >
                Suivant →
              </button>
            </div>
          )}
        </div>
      )}
    </>
  );
}
