"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { API_BASE, TOKEN_COOKIE, apiFetch } from "./api";
import type { Account } from "./types";

/**
 * Authentification de la console.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Le controle de role est fait DEUX FOIS, et ce n'est pas une
 *  duplication inutile
 * ═══════════════════════════════════════════════════════════════════
 * Ici, a la connexion : un compte qui n'est pas ADMIN se voit refuser
 * l'entree, et surtout **aucun cookie n'est pose**. Sans ce controle,
 * un coach pourrait se connecter a la console avec ses identifiants
 * habituels : il n'obtiendrait que des 403 sur chaque appel, mais il
 * verrait la coquille de l'interface, ses menus et ses libelles.
 *
 * Et cote backend, ou `/api/v1/admin/**` exige `hasRole("ADMIN")`.
 * C'est celui-la qui protege reellement les donnees — celui d'ici ne
 * protege que l'experience. Retirer le second rendrait l'API ouverte ;
 * retirer le premier rendrait la console trompeuse.
 */

const SESSION_MAX_AGE_SECONDS = 60 * 60 * 24; // 24 h, comme le JWT du backend

export interface LoginState {
  error?: string;
}

/**
 * Action de formulaire : verifie les identifiants aupres du backend, puis
 * pose le jeton dans un cookie `httpOnly`.
 *
 * L'appel a `/auth/login` se fait ici en direct (et non via `apiFetch`)
 * parce qu'il est le seul a n'avoir pas encore de jeton a transmettre.
 */
export async function login(_prev: LoginState, formData: FormData): Promise<LoginState> {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");

  if (!email || !password) {
    return { error: "Renseigne ton adresse et ton mot de passe." };
  }

  let token: string;
  try {
    const res = await fetch(`${API_BASE}/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
      cache: "no-store",
    });

    if (res.status === 401) {
      return { error: "Adresse ou mot de passe incorrect." };
    }
    if (res.status === 403) {
      // Le backend leve DisabledException -> 403 pour un compte suspendu
      // ou dont l'email n'a jamais ete verifie.
      return { error: "Ce compte est desactive." };
    }
    if (!res.ok) {
      return { error: "Connexion impossible. Le serveur repond mal." };
    }

    const body = await res.json();
    token = body.token;
    if (!token) {
      return { error: "Reponse inattendue du serveur." };
    }
  } catch {
    // Cas le plus frequent en developpement : le backend n'est pas demarre.
    return {
      error: "Serveur injoignable. Verifie que le backend tourne sur le port 8081.",
    };
  }

  // Le cookie est pose AVANT la verification du role, parce que
  // `GET /auth/me` a besoin du jeton. Il est retire aussitot si le
  // compte n'est pas administrateur.
  const store = await cookies();
  store.set(TOKEN_COOKIE, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: SESSION_MAX_AGE_SECONDS,
  });

  try {
    const account = await apiFetch<Account>("/auth/me");
    if (account.role !== "ADMIN") {
      store.delete(TOKEN_COOKIE);
      return {
        error: "Ce compte n'est pas administrateur. La console lui est fermee.",
      };
    }
  } catch {
    store.delete(TOKEN_COOKIE);
    return { error: "Impossible de verifier le compte." };
  }

  redirect("/");
}

export async function logout(): Promise<void> {
  const store = await cookies();
  store.delete(TOKEN_COOKIE);
  redirect("/connexion");
}

/**
 * Compte connecte, ou `null`.
 *
 * Utilise par la coquille de la console pour afficher l'identite et,
 * surtout, pour rediriger vers la connexion si la session a expire. Le
 * jeton dure 24 h : une console laissee ouverte la nuit se retrouve avec
 * un cookie present mais un jeton refuse, et sans ce controle chaque
 * page afficherait une erreur au lieu de renvoyer se reconnecter.
 */
export async function currentAccount(): Promise<Account | null> {
  const store = await cookies();
  if (!store.get(TOKEN_COOKIE)) return null;

  try {
    const account = await apiFetch<Account>("/auth/me");
    return account.role === "ADMIN" ? account : null;
  } catch {
    return null;
  }
}
