/**
 * Fabriques d'URL — sans aucune dependance serveur.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Pourquoi ce fichier existe separement de `api.ts`
 * ═══════════════════════════════════════════════════════════════════
 * `api.ts` importe `next/headers` pour lire le cookie de session : c'est
 * un module strictement SERVEUR. Y placer une simple fonction de
 * construction d'URL suffisait a faire echouer la compilation des qu'un
 * composant client l'importait — le bundler tirait alors tout le client
 * HTTP, et avec lui l'acces aux cookies, dans le bundle du navigateur.
 *
 * Ces helpers sont purs : une chaine entre, une chaine sort. Ils peuvent
 * donc etre appeles des deux cotes.
 */

/**
 * URL d'un justificatif de coach, servie par NOTRE relais interne.
 *
 * Le fichier n'est jamais joignable directement : il vit dans un dossier
 * prive du backend, derriere une route authentifiee. Un navigateur ne
 * pouvant pas poser d'en-tete `Authorization` sur un `<img src>`, la
 * console passe par `/api/documents/[id]`, qui detient le cookie.
 */
export function documentUrl(documentId: string): string {
  return `/api/documents/${documentId}`;
}

/**
 * URL d'un media public (avatar, capture jointe a un signalement).
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Le backend renvoie des chemins RELATIFS
 * ═══════════════════════════════════════════════════════════════════
 * `avatarUrl` et `attachmentUrl` valent `/media/<nom>` et non une adresse
 * complete — un choix deliberé cote serveur, pour que la meme reponse
 * fonctionne sur un emulateur, un telephone et en production, ou l'hote
 * n'est jamais le meme.
 *
 * Utilises tels quels dans une page web, ils sont demandes a la CONSOLE
 * (`localhost:3000/media/...`), qui ne connait pas ces fichiers : toutes
 * les images restaient cassees. L'application Flutter, elle, faisait deja
 * cette resolution (`ApiConstants.mediaUrl`) — c'est cote console qu'elle
 * manquait.
 *
 * On passe par le relais `/api/media/...` plutot que par l'adresse directe
 * du backend, pour deux raisons :
 *
 *  - le navigateur n'a pas forcement acces au backend (en production il
 *    peut etre sur un reseau prive) ;
 *  - l'origine du backend n'apparait pas dans le HTML.
 *
 * Une URL deja absolue est renvoyee telle quelle ; null/vide -> null.
 */
export function mediaUrl(path: string | null | undefined): string | null {
  if (!path) return null;
  if (path.startsWith("http://") || path.startsWith("https://")) return path;
  const clean = path.startsWith("/") ? path.slice(1) : path;
  if (!clean.startsWith("media/")) return null;
  return `/api/${clean}`;
}
