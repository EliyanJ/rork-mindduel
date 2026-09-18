import { ArrowLeft, KeyRound, Loader2, ShieldCheck, TriangleAlert } from "lucide-react";
import { Link } from "react-router-dom";

import { useAdminAuth } from "@/hooks/useAdminAuth";
import { useAuth } from "@/hooks/useAuth";

/** Google's brand mark, inlined so the button works offline. */
const GoogleMark = () => (
  <svg viewBox="0 0 48 48" className="h-5 w-5" aria-hidden="true">
    <path
      fill="#EA4335"
      d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"
    />
    <path
      fill="#4285F4"
      d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"
    />
    <path
      fill="#FBBC05"
      d="M10.53 28.59A14.5 14.5 0 0 1 9.77 24c0-1.6.28-3.14.76-4.59l-7.98-6.19A23.94 23.94 0 0 0 0 24c0 3.88.93 7.54 2.56 10.78l7.97-6.19z"
    />
    <path
      fill="#34A853"
      d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"
    />
  </svg>
);

/**
 * Single door into the admin pages: Google sign-in, restricted to the
 * allow-list. Talking to the backend additionally needs the admin API key,
 * entered separately once signed in (see the key banner in `AdminTopNav`).
 */
const AdminLogin = () => {
  const { signIn, isSigningIn, error: authError, clearError } = useAuth();
  const { rejectedEmail, accessError, retryAccess } = useAdminAuth();

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden bg-[#070a12] px-6 py-16 text-white">
      <div className="pointer-events-none absolute -left-32 top-0 h-[28rem] w-[28rem] rounded-full bg-indigo-600/20 blur-[120px]" />
      <div className="pointer-events-none absolute -right-24 bottom-0 h-[24rem] w-[24rem] rounded-full bg-amber-500/10 blur-[120px]" />

      <div className="relative w-full max-w-md">
        <Link to="/" className="mb-6 inline-flex items-center gap-2 text-sm text-white/45 transition hover:text-white">
          <ArrowLeft className="h-4 w-4" />
          Retour au site
        </Link>

        <div className="rounded-[28px] border border-white/10 bg-white/[0.035] p-8 shadow-[0_30px_80px_-40px_rgba(0,0,0,0.9)] backdrop-blur">
          <div className="mb-7 flex items-center gap-3.5">
            <span className="grid h-12 w-12 place-items-center rounded-2xl bg-gradient-to-br from-indigo-400 to-violet-600">
              <ShieldCheck className="h-6 w-6 text-white" />
            </span>
            <div>
              <h1 className="text-lg font-extrabold tracking-tight">Espace administrateur</h1>
              <p className="text-xs text-white/45">Minduel — accès réservé</p>
            </div>
          </div>

          {rejectedEmail && (
            <div className="mb-5 flex items-start gap-2.5 rounded-xl border border-amber-500/25 bg-amber-500/10 px-3.5 py-3 text-xs text-amber-200">
              <TriangleAlert className="mt-0.5 h-4 w-4 shrink-0" />
              <span>
                <strong className="font-bold">{rejectedEmail}</strong> n'est pas un compte administrateur. Connecte-toi
                avec le compte autorisé.
              </span>
            </div>
          )}

          {accessError && (
            <div role="alert" className="mb-5 rounded-xl border border-amber-500/25 p-3 text-xs text-amber-200">
              {accessError} <button type="button" onClick={retryAccess} className="underline">Réessayer</button>
            </div>
          )}
          {authError && (
            <div className="mb-5 flex items-start justify-between gap-3 rounded-xl border border-red-500/25 bg-red-500/10 px-3.5 py-3 text-xs text-red-200">
              <span>{authError}</span>
              <button type="button" onClick={clearError} className="shrink-0 font-bold underline">
                OK
              </button>
            </div>
          )}

          <button
            type="button"
            onClick={() => void signIn("google")}
            disabled={isSigningIn}
            className="flex w-full items-center justify-center gap-3 rounded-2xl bg-white px-4 py-3.5 text-sm font-bold text-[#111] transition hover:brightness-95 active:scale-[0.985] disabled:opacity-60"
          >
            {isSigningIn ? <Loader2 className="h-5 w-5 animate-spin" /> : <GoogleMark />}
            {isSigningIn ? "Connexion…" : "Continuer avec Google"}
          </button>

          <p className="mt-6 flex items-start gap-2 text-[11px] leading-relaxed text-white/30">
            <KeyRound className="mt-0.5 h-3.5 w-3.5 shrink-0" />
            Une fois connecté, il te sera demandé la clé d'accès au serveur — elle reste stockée uniquement sur cet
            appareil.
          </p>
        </div>
      </div>
    </div>
  );
};

export default AdminLogin;
