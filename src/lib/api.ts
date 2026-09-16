import { cookies } from "next/headers";

/**
 * Client HTTP vers l'API Spring, cote SERVEUR uniquement.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Pourquoi le navigateur n'appelle jamais l'API directement
 * ═══════════════════════════════════════════════════════════════════
 * Le jeton JWT vit dans un cookie `httpOnly`, donc inaccessible au
 * JavaScript de la page. C'est le seul moyen d'empecher qu'une faille
 * XSS — dans une dependance, dans un champ mal echappe — permette de
 * lire un jeton d'ADMINISTRATEUR et d'en faire ce qu'on veut pendant
 * vingt-quatre heures.
 *
 * La consequence structure toute l'application : chaque appel part d'un
 * composant serveur ou d'une action serveur, qui lit le cookie et pose
 * l'en-tete `Authorization`. Le navigateur ne voit que du HTML deja
 * rendu et les resultats d'actions serveur.
 *
 * C'est aussi ce qui rend cette console differente de l'application
 * Flutter : celle-ci stocke son jeton chiffre sur l'appareil et appelle
 * l'API en direct, ce qui est le bon compromis sur mobile ou il n'y a
 * pas de serveur intermediaire. Ici, il y en a un — autant s'en servir.
 */

/** Fichier d'environnement : voir `.env.local.example`. */
const API_BASE = process.env.API_BASE_URL ?? "http://localhost:8081/api/v1";

export const TOKEN_COOKIE = "fitforge_admin_token";

/** Erreur portant le code HTTP, pour distinguer 401, 403 et le reste. */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

async function authHeader(): Promise<Record<string, string>> {
  const store = await cookies();
  const token = store.get(TOKEN_COOKIE)?.value;
  return token ? { Authorization: `Bearer ${token}` } : {};
}

/**
 * Extrait le message d'erreur du corps de reponse.
 *
 * Le backend renvoie une forme unique (`common/dto/ApiError` :
 * status / code / message / timestamp). On affiche `message`, qui est
 * redige pour etre lu — « Seul un dossier en attente d'examen peut etre
 * refuse » vaut mieux que « Request failed with status 400 ».
 */
async function readError(res: Response): Promise<string> {
  try {
    const body = await res.json();
    if (body && typeof body.message === "string") return body.message;
  } catch {
    /* corps vide ou non JSON : on retombe sur le message generique */
  }
  return `Erreur ${res.status}`;
}

interface RequestOptions {
  method?: string;
  body?: unknown;
  /**
   * Duree de mise en cache, en secondes. Par defaut `0` : une console
   * d'administration doit montrer l'etat reel de la base, pas une page
   * rendue il y a cinq minutes. Un dossier deja traite par un collegue
   * qui reapparait comme « en attente » ferait travailler deux fois.
   */
  revalidate?: number;
}

export async function apiFetch<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { method = "GET", body, revalidate = 0 } = options;

  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers: {
      ...(await authHeader()),
      ...(body !== undefined ? { "Content-Type": "application/json" } : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
    cache: revalidate === 0 ? "no-store" : undefined,
    next: revalidate > 0 ? { revalidate } : undefined,
  });

  if (!res.ok) {
    throw new ApiError(res.status, await readError(res));
  }

  // 204 et corps vide : `res.json()` leverait sur une reponse sans contenu.
  if (res.status === 204) return undefined as T;
  const text = await res.text();
  return (text ? JSON.parse(text) : undefined) as T;
}

/**
 * Variante qui renvoie `null` au lieu de lever, pour les chargements de
 * page ou une panne ne doit pas remplacer tout l'ecran par une erreur.
 *
 * Utile la ou plusieurs blocs se chargent en parallele : si la sante de
 * l'IA est indisponible, le tableau de bord doit quand meme afficher ses
 * compteurs. Une seule requete en echec ne justifie pas une page blanche.
 */
export async function apiFetchSafe<T>(
  path: string,
  options: RequestOptions = {},
): Promise<T | null> {
  try {
    return await apiFetch<T>(path, options);
  } catch {
    return null;
  }
}

export { API_BASE };

// NOTE : `documentUrl` vivait ici et a ete deplacee dans `lib/urls.ts`.
// Ce module importe `next/headers`, il est donc STRICTEMENT serveur :
// une seule fonction utilitaire partagee suffisait a le faire entrer
// dans le bundle navigateur via un composant client, et la compilation
// echouait. Les helpers purs vont desormais dans `urls.ts`.
