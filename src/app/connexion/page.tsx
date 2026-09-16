import { redirect } from "next/navigation";
import { currentAccount } from "@/lib/auth";
import { LoginForm } from "./login-form";

/**
 * Ecran de connexion de la console.
 *
 * Il reprend le vocabulaire visuel des ecrans d'authentification de
 * l'application mobile : halos derriere une carte en verre, logo sur
 * degrade de marque, vignette qui referme la lumiere vers le centre. La
 * vignette n'y est pas decorative — sans elle, les halos touchent les
 * bords et l'ecran se lit comme un fond d'ecran ; en refermant la lumiere,
 * elle dirige le regard vers le formulaire, qui EST le contenu.
 *
 * Pas d'inclinaison 3D ici, comme sur mobile et pour la meme raison :
 * incliner une surface dans laquelle on tape du texte deplace les champs
 * sous le curseur.
 */
export default async function LoginPage() {
  // Deja connecte : on ne montre pas un formulaire de connexion a
  // quelqu'un qui a une session valide, il croirait avoir ete deconnecte.
  if (await currentAccount()) {
    redirect("/");
  }

  return (
    <main className="relative grid min-h-screen place-items-center overflow-hidden px-4 py-10">
      {/* Halos, plus marques que sur le reste de la console : ici le fond
          est le contenu, il n'y a aucun tableau a lire par-dessus. */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0"
        style={{
          background: `
            radial-gradient(40rem 30rem at 22% 18%, color-mix(in oklab, var(--color-violet) 30%, transparent), transparent 68%),
            radial-gradient(34rem 26rem at 80% 26%, color-mix(in oklab, var(--color-cyan) 20%, transparent), transparent 68%),
            radial-gradient(32rem 28rem at 52% 92%, color-mix(in oklab, var(--color-violet) 18%, transparent), transparent 70%)
          `,
        }}
      />
      {/* Vignette : referme la lumiere vers le centre. */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            "radial-gradient(70% 60% at 50% 45%, transparent 30%, rgb(8 12 26 / 0.75) 100%)",
        }}
      />

      <div className="relative w-full max-w-[26rem]">
        {/* ── Logo ─────────────────────────────────────────────── */}
        <div className="mb-8 flex flex-col items-center">
          <div
            className="depth-lg grid size-16 place-items-center rounded-2xl text-2xl font-black text-white"
            style={{
              background: "linear-gradient(135deg, var(--color-violet), var(--color-cyan))",
            }}
          >
            FF
          </div>
          <h1 className="mt-5 text-2xl font-bold tracking-tight">
            FIT<span className="font-light">FORGE</span>
          </h1>
          <p className="mt-1.5 text-xs font-semibold tracking-[0.22em] text-ink-faint uppercase">
            Console d&apos;administration
          </p>
        </div>

        {/* ── Carte en verre ───────────────────────────────────── */}
        <div className="edge-lit depth-lg rounded-3xl border border-line bg-surface/80 p-7 backdrop-blur-xl">
          <LoginForm />
        </div>

        <p className="mt-6 text-center text-xs leading-relaxed text-ink-faint">
          Reserve aux comptes administrateurs.
          <br />
          Les coachs et les adherents passent par l&apos;application mobile.
        </p>
      </div>
    </main>
  );
}
