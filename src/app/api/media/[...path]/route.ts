import { NextResponse } from "next/server";
import { API_BASE } from "@/lib/api";

/**
 * Relais vers les medias publics du backend (avatars, captures jointes).
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Pourquoi un relais alors que ces fichiers sont publics
 * ═══════════════════════════════════════════════════════════════════
 * Le backend renvoie des chemins RELATIFS (`/media/<nom>`) pour rester
 * portable entre emulateur, telephone et production. Une page web ne peut
 * pas les utiliser tels quels : le navigateur les demanderait a la console
 * elle-meme, qui ne connait pas ces fichiers.
 *
 * On pourrait reconstruire l'adresse absolue du backend cote serveur et la
 * mettre dans le HTML. Le relais est prefere pour deux raisons :
 *
 *  - **le navigateur n'a pas forcement acces au backend.** En production, il
 *    peut se trouver sur un reseau prive, joignable uniquement par la
 *    console. Une URL absolue casserait alors toutes les images.
 *  - **l'origine du backend n'apparait pas dans le HTML**, ce qui reste
 *    coherent avec le reste de la console, ou le navigateur ne parle jamais
 *    directement a Spring.
 *
 * ⚠️ A ne pas confondre avec `/api/documents/[id]`, qui sert les
 * justificatifs de coach : ceux-la sont **prives**, transitent avec le jeton
 * et interdisent toute mise en cache. Ici, ce sont des fichiers publics.
 */

/** Racine publique du backend, sans le prefixe `/api/v1`. */
const MEDIA_ORIGIN = API_BASE.replace(/\/api\/v1\/?$/, "");

/**
 * Un segment de chemin ne peut etre qu'un nom de fichier simple.
 *
 * Le backend nomme ses fichiers avec un UUID et une extension. Refuser tout
 * le reste ferme la traversee de repertoire (`..`, chemins absolus) sans
 * dependre du comportement du serveur en aval — la defense en profondeur
 * coute une ligne, la faire sauter coute la lecture de fichiers arbitraires.
 */
const SAFE_SEGMENT = /^[A-Za-z0-9._-]+$/;

export async function GET(
  _request: Request,
  context: { params: Promise<{ path: string[] }> },
) {
  const { path } = await context.params;

  if (!path?.length || !path.every((segment) => SAFE_SEGMENT.test(segment))) {
    return new NextResponse("Chemin invalide", { status: 400 });
  }

  const upstream = await fetch(`${MEDIA_ORIGIN}/media/${path.join("/")}`, {
    cache: "no-store",
  });

  if (!upstream.ok || !upstream.body) {
    // On ne recopie pas le corps d'erreur : il s'afficherait a la place de
    // l'image dans une balise <img>.
    return new NextResponse("Media introuvable", { status: upstream.status });
  }

  // Retransmis en FLUX, sans etre charge en memoire.
  return new NextResponse(upstream.body, {
    status: 200,
    headers: {
      "Content-Type": upstream.headers.get("Content-Type") ?? "application/octet-stream",
      // Les noms de fichiers sont des UUID : remplacer un avatar produit un
      // nouveau nom, jamais un nouveau contenu sous le meme nom. Le cache est
      // donc sur du contenu immuable.
      //
      // `private` malgre tout : ce sont des photos de personnes, elles n'ont
      // rien a faire dans un cache partage entre plusieurs utilisateurs.
      "Cache-Control": "private, max-age=3600",
    },
  });
}
