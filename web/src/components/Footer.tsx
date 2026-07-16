import { Link } from "react-router-dom";

const Footer = () => {
  return (
    <footer className="border-t border-white/10 bg-[#080b13] px-6 py-14 text-white">
      <div className="mx-auto grid max-w-6xl gap-10 sm:grid-cols-2 md:grid-cols-4">
        <div className="sm:col-span-2 md:col-span-1">
          <Link to="/" className="flex items-center gap-2.5">
            <img src="/logo.png" alt="Minduel" className="h-8 w-8 rounded-[8px]" />
            <span className="text-base font-extrabold tracking-tight">Minduel</span>
          </Link>
          <p className="mt-4 max-w-xs text-sm leading-relaxed text-white/50">
            Le quiz de culture générale qui se joue en duel. Apprends, révise, affronte.
          </p>
        </div>

        <div>
          <p className="mb-4 text-xs font-semibold uppercase tracking-wider text-white/40">Produit</p>
          <ul className="space-y-3 text-sm text-white/60">
            <li>
              <a href="/#fonctionnalites" className="transition hover:text-white">
                Fonctionnalités
              </a>
            </li>
            <li>
              <a href="/#duels" className="transition hover:text-white">
                Duels classés
              </a>
            </li>
            <li>
              <a href="/#avis" className="transition hover:text-white">
                Avis
              </a>
            </li>
            <li>
              <a href="/#faq" className="transition hover:text-white">
                FAQ
              </a>
            </li>
          </ul>
        </div>

        <div>
          <p className="mb-4 text-xs font-semibold uppercase tracking-wider text-white/40">Légal</p>
          <ul className="space-y-3 text-sm text-white/60">
            <li>
              <Link to="/privacy" className="transition hover:text-white">
                Confidentialité
              </Link>
            </li>
            <li>
              <Link to="/terms" className="transition hover:text-white">
                Conditions d'utilisation
              </Link>
            </li>
            <li>
              <Link to="/support" className="transition hover:text-white">
                Support
              </Link>
            </li>
          </ul>
        </div>

        <div>
          <p className="mb-4 text-xs font-semibold uppercase tracking-wider text-white/40">Contact</p>
          <ul className="space-y-3 text-sm text-white/60">
            <li>
              <a href="mailto:support@minduel.app" className="transition hover:text-white">
                support@minduel.app
              </a>
            </li>
          </ul>
        </div>
      </div>

      <div className="mx-auto mt-12 flex max-w-6xl flex-col items-center justify-between gap-4 border-t border-white/10 pt-6 text-xs text-white/40 sm:flex-row">
        <p>© {new Date().getFullYear()} Minduel. Tous droits réservés.</p>
        <div className="flex items-center gap-4">
          <p>Disponible sur l'App Store.</p>
          <Link to="/admin-generator" className="text-white/20 transition hover:text-white/50">
            Admin
          </Link>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
