import { memo } from "react";

import { cn } from "@/lib/utils";
import { APP_STORE_URL } from "@/lib/site";

const AppleLogo = ({ className }: { className?: string }) => (
  <svg viewBox="0 0 384 512" aria-hidden className={className} fill="currentColor">
    <path d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.7 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-56.6-164.2c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26.1 2 49.9-11.4 69.5-34.3z" />
  </svg>
);

type Props = { size?: "md" | "lg"; className?: string; onDark?: boolean };

/** Official-looking App Store download button linking to the live Minduel listing. */
const AppStoreButton = ({ size = "md", className, onDark = false }: Props) => (
  <a
    href={APP_STORE_URL}
    target="_blank"
    rel="noreferrer"
    aria-label="Télécharger Minduel sur l'App Store"
    className={cn(
      "group inline-flex items-center gap-3 rounded-2xl font-body transition-all duration-150 active:translate-y-[3px]",
      onDark
        ? "bg-white text-site-ink shadow-[0_5px_0_rgba(0,0,0,0.25)] hover:brightness-95 active:shadow-[0_2px_0_rgba(0,0,0,0.25)]"
        : "bg-site-ink text-white shadow-[0_5px_0_#000] hover:bg-black active:shadow-[0_2px_0_#000]",
      size === "lg" ? "px-7 py-4" : "px-5 py-3",
      className,
    )}
  >
    <AppleLogo className={size === "lg" ? "h-8 w-8" : "h-6 w-6"} />
    <span className="text-left leading-tight">
      <span className={cn("block font-medium opacity-70", size === "lg" ? "text-xs" : "text-[11px]")}>
        Télécharger sur l'
      </span>
      <span className={cn("-mt-0.5 block font-display font-extrabold tracking-tight", size === "lg" ? "text-2xl" : "text-lg")}>
        App Store
      </span>
    </span>
  </a>
);

export default memo(AppStoreButton);
