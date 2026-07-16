import { useEffect, useState } from "react";

import { Menu, X } from "lucide-react";
import { Link, useLocation } from "react-router-dom";

const NAV_LINKS = [
  { label: "Fonctionnalités", href: "#fonctionnalites" },
  { label: "Duels", href: "#duels" },
  { label: "Avis", href: "#avis" },
  { label: "FAQ", href: "#faq" },
];

const Navbar = () => {
  const [scrolled, setScrolled] = useState<boolean>(false);
  const [menuOpen, setMenuOpen] = useState<boolean>(false);
  const location = useLocation();
  const isHome = location.pathname === "/";

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const handleNavClick = (href: string) => {
    setMenuOpen(false);
    if (!isHome) return;
    const el = document.querySelector(href);
    if (el) el.scrollIntoView({ behavior: "smooth" });
  };

  return (
    <header
      className={`fixed inset-x-0 top-0 z-50 transition-all duration-300 ${
        scrolled ? "border-b border-white/10 bg-[#0b0f1a]/85 backdrop-blur-lg" : "border-b border-transparent bg-transparent"
      }`}
    >
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-6">
        <Link to="/" className="flex items-center gap-2.5">
          <img
            src="/logo.png"
            alt="Minduel"
            className="h-9 w-9 rounded-[10px] shadow-[0_0_0_1px_rgba(255,255,255,0.08)]"
          />
          <span className="text-lg font-extrabold tracking-tight text-white">Minduel</span>
        </Link>

        <nav className="hidden items-center gap-1 md:flex">
          {NAV_LINKS.map((link) =>
            isHome ? (
              <a
                key={link.href}
                href={link.href}
                onClick={(e) => {
                  e.preventDefault();
                  handleNavClick(link.href);
                }}
                className="rounded-full px-4 py-2 text-sm font-medium text-white/70 transition hover:text-white"
              >
                {link.label}
              </a>
            ) : (
              <Link
                key={link.href}
                to={`/${link.href}`}
                className="rounded-full px-4 py-2 text-sm font-medium text-white/70 transition hover:text-white"
              >
                {link.label}
              </Link>
            ),
          )}
        </nav>

        <div className="hidden md:block">
          <a
            href="#telecharger"
            onClick={(e) => {
              e.preventDefault();
              handleNavClick("#telecharger");
            }}
            className="inline-flex items-center gap-2 rounded-full bg-gradient-to-r from-amber-400 to-orange-500 px-5 py-2.5 text-sm font-bold text-[#0b0f1a] shadow-lg shadow-orange-500/20 transition hover:brightness-105 active:scale-[0.97]"
          >
            Télécharger
          </a>
        </div>

        <button
          type="button"
          onClick={() => setMenuOpen((v) => !v)}
          className="inline-flex h-10 w-10 items-center justify-center rounded-full text-white/80 transition hover:bg-white/10 md:hidden"
          aria-label="Ouvrir le menu"
        >
          {menuOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
        </button>
      </div>

      {menuOpen && (
        <div className="border-t border-white/10 bg-[#0b0f1a]/95 px-6 pb-6 pt-2 backdrop-blur-lg md:hidden">
          <nav className="flex flex-col gap-1">
            {NAV_LINKS.map((link) => (
              <a
                key={link.href}
                href={link.href}
                onClick={(e) => {
                  e.preventDefault();
                  handleNavClick(link.href);
                }}
                className="rounded-xl px-3 py-3 text-sm font-medium text-white/80 transition hover:bg-white/5"
              >
                {link.label}
              </a>
            ))}
            <a
              href="#telecharger"
              onClick={(e) => {
                e.preventDefault();
                handleNavClick("#telecharger");
              }}
              className="mt-2 inline-flex items-center justify-center gap-2 rounded-full bg-gradient-to-r from-amber-400 to-orange-500 px-5 py-3 text-sm font-bold text-[#0b0f1a]"
            >
              Télécharger l'app
            </a>
          </nav>
        </div>
      )}
    </header>
  );
};

export default Navbar;
