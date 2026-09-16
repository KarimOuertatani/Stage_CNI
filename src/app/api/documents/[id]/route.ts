import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { API_BASE, TOKEN_COOKIE } from "@/lib/api";

/**
 * Relais vers un justificatif de coach (piece d'identite, diplome).
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Pourquoi ces fichiers ne peuvent pas etre affiches directement
 * ═══════════════════════════════════════════════════════════════════
 * Ils ne vivent pas dans `/media/**`, qui est public, mais dans un
 * dossier prive servi par une route authentifiee — parce qu'une piece
 * d'identite deposee dans un dossier public serait lisible par quiconque
 * connait son URL, et qu'un nom de fichier aleatoire ne protege rien : il
 * voyage dans les journaux d'acces, les historiques et les presse-papiers.
 *
 * Or un navigateur ne peut pas poser d'en-tete `Authorization` sur un
 * `<img src>` ou un `<iframe>`. Cette route sert donc d'intermediaire :
 * elle detient le cookie, appelle l'API avec le jeton, et retransmet le
 * flux au navigateur.
 *
 * ⚠️ Les en-tetes de cache sont volontairement restrictifs. Ces fichiers
 * ne doivent finir ni dans un cache partage, ni sur le disque du poste de
 * l'administrateur apres la fermeture de l'onglet.
 */
export async function GET(_request: Request, context: { params: Promise<{ id: string }> }) {
  const { id } = await context.params;

  const store = await cookies();
  const token = store.get(TOKEN_COOKIE)?.value;
  if (!token) {
    return new NextResponse("Non authentifie", { status: 401 });
  }

  const upstream = await fetch(`${API_BASE}/coach-application/documents/${id}/file`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: "no-store",
  });

  if (!upstream.ok || !upstream.body) {
    // On ne recopie pas le corps d'erreur du backend : il n'apporte rien
    // dans une balise <img> et pourrait s'afficher a la place de l'image.
    return new NextResponse("Justificatif indisponible", { status: upstream.status });
  }

  // Le corps est retransmis en FLUX, sans etre charge en memoire : un PDF
  // de 10 Mo par document, sur un dossier qui peut en compter plusieurs,
  // n'a aucune raison de transiter par le tas du serveur Node.
  return new NextResponse(upstream.body, {
    status: 200,
    headers: {
      "Content-Type": upstream.headers.get("Content-Type") ?? "application/octet-stream",
      "Content-Disposition":
        upstream.headers.get("Content-Disposition") ?? "inline",
      "Cache-Control": "private, no-store, max-age=0",
    },
  });
}
