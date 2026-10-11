/** Public App Store page of the live Minduel app. */
export const APP_STORE_URL = "https://apps.apple.com/fr/app/minduel-duels-de-culture-g/id6788570245";

export const SUPPORT_EMAIL = "support@minduel.app";

export type Subject = { id: string; name: string; color: string };

/** Themes as shown in the app, with their in-app accent colors. */
export const SUBJECTS: Subject[] = [
  { id: "histoire", name: "Histoire", color: "#E8590C" },
  { id: "sciences", name: "Sciences", color: "#7048E8" },
  { id: "geographie", name: "Géographie", color: "#1C7ED6" },
  { id: "litterature", name: "Littérature", color: "#0CA678" },
  { id: "arts", name: "Arts & Musique", color: "#E64980" },
  { id: "nature", name: "Nature & Animaux", color: "#2F9E44" },
  { id: "technologie", name: "Tech & Espace", color: "#F59F00" },
  { id: "football", name: "Football", color: "#37B24D" },
];
