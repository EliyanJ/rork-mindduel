import { useCallback, useEffect, useState } from "react";

import { Menu, X } from "lucide-react";
import { Link, useLocation, useNavigate } from "react-router-dom";

import { cn } from "@/lib/utils";
import { APP_STORE_URL } from "@/lib/site";

const NAV_LINKS = [
  { label: "Le jeu", href: "#jeu" },
  { label: "Thèmes", href: "#themes" },
  { label: "Duels", href: "#duels" },
  { label: "FAQ", href: "#faq" },
];

const Navbar = () => {
  const [scrolled, setScrolled] = useState<boolean>(false);
  const [menuOpen, setMenuOpen] = useState<boolean>(false);
  const location = useLocation();
  const navigate = useNavigate();
  const isHome = location.pathname === "/";

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    document.body.style.overflow = menuOpen ? "hidden" : "";
    return () => {
      document.body.style.overflow = "";
    };
  }, [menuOpen]);

  const goTo = useCallback(
    (href: string) => {
      setMenuOpen(false);
      if (!isHome) {
        navigate(`/${href}`);
        return;
      }
      document.querySelector(href)?.scrollIntoView({ behavior: "smooth", block: "start" });
    },
    [isHome, navigate],
  );

  return (
    <header
      className={cn(
        "fixed inset-x-0 top-0 z-50 font-body transition-all duration-300",
        scrolled || menuOpen ? "border-b border-site-line bg-site-bg/90 backdrop-blur-xl" : "border-b border-transparent",
      )}
    >
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-5 sm:px-6">
        <Link to="/" className="flex items-center gap-2.5" onClick={() => setMenuOpen(false)}>
          <img src="/site/app-icon.png" alt="" className="h-9 w-9 rounded-[11px] shadow-[0_2px_0_rgba(36,22,14,0.15)]" />
          <span className="font-display text-xl font-extrabold tracking-tight text-site-orange">Minduel</span>
        </Link>

        <nav className="hidden items-center gap-1 md:flex" aria-label="Navigation principale">
          {NAV_LINKS.map((link) => (
            <a
              key={link.href}
              href={`/${link.href}`}
              onClick={(e) => {
                e.preventDefault();
                goTo(link.href);
              }}
              className="rounded-full px-4 py-2 text-[15px] font-semibold text-site-muted transition hover:bg-site-line/60 hover:text-site-ink"
            >
              {link.label}
            </a>
          ))}
        </nav>

        <a
          href={APP_STORE_URL}
          target="_blank"
          rel="noreferrer"
          className="hidden rounded-full bg-site-orange px-5 py-2.5 text-sm font-bold text-white shadow-[0_4px_0_#C24F00] transition-all hover:brightness-105 active:translate-y-[2px] active:shadow-[0_2px_0_#C24F00] md:inline-flex"
        >
          Télécharger
        </a>

        <button
          type="button"
          onClick={() => setMenuOpen((v) => !v)}
          className="inline-flex h-11 w-11 items-center justify-center rounded-full text-site-ink transition hover:bg-site-line/60 md:hidden"
          aria-label={menuOpen ? "Fermer le menu" : "Ouvrir le menu"}
          aria-expanded={menuOpen}
        >
          {menuOpen ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
        </button>
      </div>

      {menuOpen && (
        <div className="h-[calc(100dvh-4rem)] border-t border-site-line bg-site-bg px-5 pb-8 pt-4 md:hidden">
          <nav className="flex flex-col gap-1" aria-label="Navigation mobile">
            {NAV_LINKS.map((link, i) => (
              <a
                key={link.href}
                href={`/${link.href}`}
                onClick={(e) => {
                  e.preventDefault();
                  goTo(link.href);
                }}
                style={{ animationDelay: `${i * 40}ms` }}
                className="animate-pop-in rounded-2xl px-4 py-4 font-display text-2xl font-extrabold text-site-ink transition active:bg-site-line/60"
              >
                {link.label}
              </a>
            ))}
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noreferrer"
              className="mt-6 inline-flex items-center justify-center rounded-2xl bg-site-orange px-5 py-4 text-base font-bold text-white shadow-[0_5px_0_#C24F00] active:translate-y-[3px] active:shadow-[0_2px_0_#C24F00]"
            >
              Télécharger gratuitement
            </a>
          </nav>
        </div>
      )}
    </header>
  );
};

export default Navbar;
