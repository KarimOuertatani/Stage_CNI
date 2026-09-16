import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

/**
 * Inter en `display: swap` : le texte s'affiche immediatement dans la
 * police systeme puis bascule. Une console qui reste blanche le temps de
 * telecharger sa police donne l'impression d'un serveur lent, alors que
 * les donnees sont deja la.
 */
const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

export const metadata: Metadata = {
  title: "FitForge — Console d'administration",
  description:
    "Validation des coachs, gestion des membres, signalements et supervision de l'IA.",
  // Une console interne n'a rien a faire dans un index de moteur de recherche.
  robots: { index: false, follow: false },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    /*
     * `suppressHydrationWarning` sur <html> — et sur lui SEUL.
     *
     * Les extensions de navigateur (assistants, correcteurs, gestionnaires de
     * mots de passe) posent leurs propres attributs sur <html> et <body> AVANT
     * que React ne prenne la main : `bbai-tooltip-injected`, `data-lt-installed`,
     * `cz-shortcut-listen`… React compare alors le HTML rendu par le serveur au
     * DOM reel, trouve un attribut de plus, et signale une divergence
     * d'hydratation. Le code n'y est pour rien, et il n'y a aucun moyen de
     * l'empecher : ces extensions s'executent avant nous.
     *
     * ⚠️ Ce drapeau ne masque QUE les attributs de CET element — il ne s'etend
     * pas aux enfants. Une vraie divergence dans une page (une date formatee,
     * un `Math.random()`, une branche `typeof window`) sera donc toujours
     * signalee. Le poser sur <body> ou plus bas, en revanche, etoufferait de
     * vrais defauts.
     */
    <html lang="fr" className={inter.variable} suppressHydrationWarning>
      <body className="min-h-screen antialiased">
        <div className="ambient" aria-hidden />
        <div className="relative z-10">{children}</div>
      </body>
    </html>
  );
}
