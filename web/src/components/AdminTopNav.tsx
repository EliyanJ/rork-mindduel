import { BadgeCheck, Gauge, Home, LogOut, Route, ShieldCheck, Sparkles, SlidersHorizontal, Users } from "lucide-react";
import { Link, useLocation } from "react-router-dom";

import { useAdminAuth } from "@/hooks/useAdminAuth";

const TABS = [
  { to: "/admin-generator", label: "Générateur", icon: Sparkles },
  { to: "/admin-review", label: "Modération", icon: BadgeCheck },
  { to: "/admin-calibration", label: "Calibrage", icon: Gauge },
  { to: "/admin-path", label: "Parcours", icon: Route },
  { to: "/admin-users", label: "Utilisateurs", icon: Users },
] as const;

/**
 * Persistent admin navigation, always visible above whatever tool is open, so
 * every sub-page is one click away and never asks for a password again.
 */
const AdminTopNav = () => {
  const { pathname } = useLocation();
  const { session, signOutAdmin } = useAdminAuth();

  return (
    <div className="sticky top-0 z-50 border-b border-white/10 bg-[#05070d]/95 backdrop-blur-xl">
      <div className="mx-auto flex max-w-[1600px] flex-wrap items-center gap-x-4 gap-y-2 px-4 py-2.5">
        <Link to="/" className="flex items-center gap-2">
          <span className="grid h-7 w-7 place-items-center rounded-lg bg-gradient-to-br from-indigo-400 to-violet-600">
            <ShieldCheck className="h-4 w-4 text-white" />
          </span>
          <span className="text-sm font-extrabold tracking-tight text-white">Admin Minduel</span>
        </Link>

        <nav className="flex items-center gap-1 rounded-xl border border-white/10 bg-white/[0.03] p-1">
          {TABS.map(({ to, label, icon: Icon }) => {
            const active = pathname === to;
            return (
              <Link
                key={to}
                to={to}
                aria-current={active ? "page" : undefined}
                className={`flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-bold transition ${
                  active
                    ? "bg-indigo-500 text-white shadow-[0_6px_18px_-8px_rgba(99,102,241,0.9)]"
                    : "text-white/55 hover:bg-white/[0.07] hover:text-white"
                }`}
              >
                <Icon className="h-3.5 w-3.5" />
                {label}
              </Link>
            );
          })}
        </nav>

        <div className="ml-auto flex items-center gap-2">
          <Link
            to="/"
            className="hidden items-center gap-1.5 rounded-lg px-2.5 py-1.5 text-xs font-semibold text-white/45 transition hover:bg-white/[0.06] hover:text-white sm:flex"
          >
            <Home className="h-3.5 w-3.5" />
            Site
          </Link>
          {session && (
            <span className="hidden items-center gap-1.5 rounded-lg border border-white/10 bg-white/[0.03] px-2.5 py-1.5 text-[11px] font-semibold text-white/50 md:flex">
              <SlidersHorizontal className="h-3 w-3 text-indigo-300" />
              {session.label}
            </span>
          )}
          <button
            type="button"
            onClick={signOutAdmin}
            className="flex items-center gap-1.5 rounded-lg border border-white/10 px-2.5 py-1.5 text-xs font-bold text-white/55 transition hover:border-red-500/40 hover:bg-red-500/10 hover:text-red-300"
          >
            <LogOut className="h-3.5 w-3.5" />
            Quitter
          </button>
        </div>
      </div>
    </div>
  );
};

export default AdminTopNav;
