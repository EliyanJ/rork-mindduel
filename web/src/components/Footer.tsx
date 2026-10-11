import { Link } from "react-router-dom";

import { APP_STORE_URL, SUPPORT_EMAIL } from "@/lib/site";

const Footer = () => {
  return (
    <footer className="border-t border-site-line bg-white px-6 pb-28 pt-14 font-body text-site-ink md:pb-12">
      <div className="mx-auto grid max-w-6xl gap-10 sm:grid-cols-2 md:grid-cols-4">
        <div className="sm:col-span-2 md:col-span-1">
          <Link to="/" className="flex items-center gap-2.5">
            <img src="/site/app-icon.png" alt="" className="h-9 w-9 rounded-[11px]" />
            <span className="font-display text-lg font-extrabold tracking-tight text-site-orange">Minduel</span>
          </Link>
          <p className="mt-4 max-w-xs text-sm leading-relaxed text-site-muted">
            Le quiz de culture générale qui se joue en duel. Apprends, révise, affronte.
          </p>
        </div>

        <div>
          <p className="mb-4 text-xs font-bold uppercase tracking-wider text-site-muted/70">L'app</p>
          <ul className="space-y-3 text-sm font-medium text-site-muted">
            <li><a href="/#jeu" className="transition hover:text-site-orange">Le jeu</a></li>
            <li><a href="/#themes" className="transition hover:text-site-orange">Thèmes</a></li>
            <li><a href="/#duels" className="transition hover:text-site-orange">Duels classés</a></li>
            <li>
              <a href={APP_STORE_URL} target="_blank" rel="noreferrer" className="transition hover:text-site-orange">
                App Store
              </a>
            </li>
          </ul>
        </div>

        <div>
          <p className="mb-4 text-xs font-bold uppercase tracking-wider text-site-muted/70">Légal</p>
          <ul className="space-y-3 text-sm font-medium text-site-muted">
            <li><Link to="/privacy" className="transition hover:text-site-orange">Confidentialité</Link></li>
            <li><Link to="/terms" className="transition hover:text-site-orange">Conditions d'utilisation</Link></li>
            <li><Link to="/support" className="transition hover:text-site-orange">Support</Link></li>
          </ul>
        </div>

        <div>
          <p className="mb-4 text-xs font-bold uppercase tracking-wider text-site-muted/70">Contact</p>
          <a href={`mailto:${SUPPORT_EMAIL}`} className="text-sm font-medium text-site-muted transition hover:text-site-orange">
            {SUPPORT_EMAIL}
          </a>
        </div>
      </div>

      <div className="mx-auto mt-12 flex max-w-6xl flex-col items-center justify-between gap-3 border-t border-site-line pt-6 text-xs text-site-muted sm:flex-row">
        <p>© {new Date().getFullYear()} Minduel. Tous droits réservés.</p>
        <Link to="/admin" className="text-site-muted/40 transition hover:text-site-muted">
          Admin
        </Link>
      </div>
    </footer>
  );
};

export default Footer;
