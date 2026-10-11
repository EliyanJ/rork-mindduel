import { useState } from "react";

import { Brain, ChevronDown, Flame, Globe2, Repeat, Star, Swords, Trophy, Users, Zap } from "lucide-react";

import AppStoreButton from "@/components/AppStoreButton";
import Footer from "@/components/Footer";
import Navbar from "@/components/Navbar";
import { APP_STORE_URL, SUBJECTS } from "@/lib/site";
import { cn } from "@/lib/utils";

const FEATURES = [
  {
    icon: Brain,
    color: "#FF6B00",
    title: "Parcours de connaissances",
    description: "Progresse chapitre après chapitre, du QCM à l'anagramme, à travers 8 thèmes variés.",
  },
  {
    icon: Repeat,
    color: "#1CB0F6",
    title: "Révisions intelligentes",
    description: "Les notions ratées reviennent au bon moment pour s'ancrer durablement dans ta mémoire.",
  },
  {
    icon: Swords,
    color: "#FF3D8B",
    title: "Duels en temps réel",
    description: "Affronte de vrais joueurs sur les mêmes questions, au même moment.",
  },
  {
    icon: Globe2,
    color: "#7048E8",
    title: "Classement mondial",
    description: "Chaque duel fait évoluer ton score. Réponse juste et rapide = plus de points.",
  },
  {
    icon: Users,
    color: "#3DD62C",
    title: "Défie tes amis",
    description: "Ajoute tes amis avec leur code et comparez vos classements et vos progressions.",
  },
  {
    icon: Flame,
    color: "#FFC700",
    title: "Séries quotidiennes",
    description: "Garde ta flamme allumée avec un objectif quotidien qui te correspond.",
  },
];

const STEPS = [
  { title: "Choisis ton thème", description: "Histoire, sciences, géo, foot… commence par ce qui te plaît." },
  { title: "Apprends à ton rythme", description: "Des leçons courtes, des révisions au bon moment." },
  { title: "Lance un duel", description: "Affronte un joueur de ton niveau et grimpe au classement." },
];

const TESTIMONIALS = [
  {
    name: "Camille R.",
    text: "Le duel en temps réel change tout. J'apprends sans m'en rendre compte et je progresse dans le classement chaque semaine.",
  },
  {
    name: "Thomas B.",
    text: "Les révisions sont bluffantes, les questions que j'avais ratées reviennent pile au bon moment.",
  },
  {
    name: "Lina M.",
    text: "Plein de thèmes différents, jamais lassant. Les anagrammes et les textes à trous cassent la routine du QCM.",
  },
];

const FAQ = [
  {
    q: "Minduel est-elle gratuite ?",
    a: "Oui, tu peux apprendre et jouer gratuitement. Un abonnement Premium optionnel débloque tous les thèmes et des fonctions supplémentaires. Les prix sont affichés dans l'app, selon l'App Store.",
  },
  {
    q: "Comment fonctionnent les duels classés ?",
    a: "Tu es mis en relation avec un joueur de ton niveau, vous répondez aux mêmes questions au même moment. Une bonne réponse rapide rapporte plus de points qu'une réponse lente.",
  },
  {
    q: "Sur quelles plateformes Minduel est disponible ?",
    a: "Minduel est disponible sur iPhone et iPad via l'App Store. Une version Android est à l'étude.",
  },
  {
    q: "Faut-il un compte pour jouer ?",
    a: "Tu peux apprendre et réviser sans compte. Pour les duels en ligne et le classement mondial, une connexion Apple ou Google est nécessaire.",
  },
];

const STATS = [
  { value: "3 000+", label: "Questions" },
  { value: "8", label: "Thèmes" },
  { value: "68", label: "Chapitres" },
  { value: "1v1", label: "Duels en direct" },
];

const FaqItem = ({ q, a }: { q: string; a: string }) => {
  const [open, setOpen] = useState<boolean>(false);
  return (
    <div className="overflow-hidden rounded-2xl border-2 border-site-line bg-white">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        className="flex w-full items-center justify-between gap-4 px-5 py-4 text-left"
      >
        <span className="text-[15px] font-bold text-site-ink sm:text-base">{q}</span>
        <ChevronDown className={cn("h-5 w-5 shrink-0 text-site-muted transition-transform", open && "rotate-180")} />
      </button>
      {open && <p className="animate-pop-in px-5 pb-5 text-[15px] leading-relaxed text-site-muted">{a}</p>}
    </div>
  );
};

const SectionTitle = ({ kicker, title }: { kicker: string; title: string }) => (
  <div className="mx-auto mb-12 max-w-2xl text-center">
    <p className="mb-3 text-sm font-bold uppercase tracking-wider text-site-orange">{kicker}</p>
    <h2 className="font-display text-3xl font-extrabold tracking-tight text-site-ink sm:text-[2.6rem] sm:leading-[1.1]">
      {title}
    </h2>
  </div>
);

const Index = () => {
  return (
    <div className="min-h-screen bg-site-bg font-body text-site-ink">
      <Navbar />

      {/* Hero */}
      <section className="relative overflow-hidden pb-16 pt-28 sm:pt-36">
        <div
          aria-hidden
          className="pointer-events-none absolute -right-40 -top-40 h-[520px] w-[520px] rounded-full bg-site-orange/15 blur-3xl"
        />
        <div
          aria-hidden
          className="pointer-events-none absolute -left-40 top-40 h-[420px] w-[420px] rounded-full bg-site-pink/10 blur-3xl"
        />
        <div className="relative mx-auto grid max-w-6xl gap-14 px-5 sm:px-6 lg:grid-cols-[1.05fr_0.95fr] lg:items-center">
          <div className="text-center lg:text-left">
            <div className="mb-6 inline-flex items-center gap-2 rounded-full border-2 border-site-line bg-white px-4 py-1.5 text-sm font-semibold text-site-muted">
              <Star className="h-4 w-4 fill-site-gold text-site-gold" />
              Le quiz de culture G qui se joue en duel
            </div>
            <h1 className="font-display text-[2.6rem] font-extrabold leading-[1.02] tracking-tight sm:text-6xl lg:text-7xl">
              Apprends. Révise.
              <br />
              <span className="bg-gradient-to-r from-site-orange to-site-pink bg-clip-text text-transparent">
                Gagne tes duels.
              </span>
            </h1>
            <p className="mx-auto mt-6 max-w-xl text-lg leading-relaxed text-site-muted lg:mx-0">
              Histoire, sciences, géographie, foot et plus : progresse en quelques minutes par jour,
              puis affronte de vrais joueurs en temps réel.
            </p>

            <div className="mt-9 flex flex-col items-center gap-3 lg:items-start">
              <AppStoreButton size="lg" />
              <p className="text-sm font-medium text-site-muted">Gratuit sur iPhone et iPad</p>
            </div>
          </div>

          <div className="relative mx-auto flex w-full max-w-md items-center justify-center">
            <img
              src="/site/mascot-duel.webp"
              alt=""
              className="absolute -left-4 bottom-0 z-10 w-28 animate-float drop-shadow-xl sm:-left-10 sm:w-40"
            />
            <div className="relative flex gap-4 sm:gap-5">
              <img
                src="/screenshot-home.png"
                alt="Parcours d'apprentissage Minduel"
                className="w-[160px] -rotate-3 rounded-[2rem] border-[6px] border-white shadow-[0_24px_50px_-12px_rgba(36,22,14,0.35)] sm:w-[210px]"
              />
              <img
                src="/screenshot-3.png"
                alt="Duel en temps réel Minduel"
                className="mt-12 w-[160px] rotate-3 rounded-[2rem] border-[6px] border-white shadow-[0_24px_50px_-12px_rgba(36,22,14,0.35)] sm:w-[210px]"
              />
            </div>
          </div>
        </div>
      </section>

      {/* Stats */}
      <section className="px-5 sm:px-6">
        <div className="mx-auto grid max-w-5xl grid-cols-2 gap-3 sm:grid-cols-4">
          {STATS.map((s) => (
            <div key={s.label} className="rounded-3xl border-2 border-site-line bg-white px-4 py-5 text-center">
              <p className="font-display text-3xl font-extrabold text-site-ink">{s.value}</p>
              <p className="mt-1 text-xs font-bold uppercase tracking-wider text-site-muted">{s.label}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Themes */}
      <section id="themes" className="scroll-mt-20 px-5 py-24 sm:px-6">
        <div className="mx-auto max-w-6xl">
          <SectionTitle kicker="Thèmes" title="Un univers pour chaque curiosité" />
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 sm:gap-4">
            {SUBJECTS.map((s) => (
              <div
                key={s.id}
                className="group flex flex-col items-center rounded-3xl border-2 bg-white p-4 text-center transition hover:-translate-y-1"
                style={{ borderColor: `${s.color}33`, boxShadow: `0 5px 0 ${s.color}33` }}
              >
                <img
                  src={`/site/subject-${s.id}.webp`}
                  alt=""
                  loading="lazy"
                  className="h-20 w-20 object-contain transition-transform group-hover:scale-110 sm:h-24 sm:w-24"
                />
                <p className="mt-2 text-[15px] font-extrabold" style={{ color: s.color }}>
                  {s.name}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Features */}
      <section id="jeu" className="scroll-mt-20 bg-white px-5 py-24 sm:px-6">
        <div className="mx-auto max-w-6xl">
          <SectionTitle kicker="Le jeu" title="Tout ce qu'il faut pour progresser" />
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {FEATURES.map((f) => (
              <div key={f.title} className="rounded-3xl border-2 border-site-line bg-site-bg p-6">
                <div
                  className="mb-4 flex h-12 w-12 items-center justify-center rounded-2xl"
                  style={{ backgroundColor: f.color, boxShadow: `0 4px 0 ${f.color}66` }}
                >
                  <f.icon className="h-6 w-6 text-white" strokeWidth={2.5} />
                </div>
                <h3 className="mb-2 text-lg font-extrabold text-site-ink">{f.title}</h3>
                <p className="text-[15px] leading-relaxed text-site-muted">{f.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Duels */}
      <section id="duels" className="scroll-mt-20 px-5 py-24 sm:px-6">
        <div className="mx-auto grid max-w-6xl gap-14 lg:grid-cols-2 lg:items-center">
          <div>
            <p className="mb-3 text-sm font-bold uppercase tracking-wider text-site-orange">Duels classés</p>
            <h2 className="mb-5 font-display text-3xl font-extrabold tracking-tight sm:text-[2.6rem] sm:leading-[1.1]">
              Chaque victoire te fait grimper au classement
            </h2>
            <p className="mb-10 max-w-lg text-lg text-site-muted">
              Un joueur de ton niveau, les mêmes questions au même moment. Réponds vite et juste pour
              gagner le plus de points.
            </p>
            <ol className="space-y-5">
              {STEPS.map((s, i) => (
                <li key={s.title} className="flex gap-4">
                  <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-site-orange font-display text-lg font-extrabold text-white shadow-[0_4px_0_#C24F00]">
                    {i + 1}
                  </span>
                  <div>
                    <h3 className="font-extrabold text-site-ink">{s.title}</h3>
                    <p className="text-[15px] text-site-muted">{s.description}</p>
                  </div>
                </li>
              ))}
            </ol>
          </div>

          <div className="relative mx-auto w-full max-w-sm">
            <img
              src="/site/mascot-trophy.webp"
              alt=""
              loading="lazy"
              className="absolute -right-6 -top-16 z-10 w-28 animate-float drop-shadow-xl sm:w-32"
            />
            <div className="rounded-[2rem] border-2 border-site-line bg-white p-6 shadow-[0_8px_0_#F0E4D6]">
              <div className="mb-5 flex items-center justify-between">
                <span className="text-xs font-bold uppercase tracking-wider text-site-muted">Duel classé</span>
                <Trophy className="h-5 w-5 text-site-gold" />
              </div>
              <div className="mb-5 flex items-center justify-between rounded-2xl bg-site-bg p-4">
                <div className="text-center">
                  <div className="mx-auto mb-2 flex h-12 w-12 items-center justify-center rounded-full bg-site-sky/15 text-xl">🦊</div>
                  <p className="text-xs font-semibold text-site-muted">Toi</p>
                  <p className="font-display text-xl font-extrabold">1 248</p>
                </div>
                <Swords className="h-7 w-7 text-site-orange" />
                <div className="text-center">
                  <div className="mx-auto mb-2 flex h-12 w-12 items-center justify-center rounded-full bg-site-pink/15 text-xl">🐼</div>
                  <p className="text-xs font-semibold text-site-muted">Léa</p>
                  <p className="font-display text-xl font-extrabold">1 231</p>
                </div>
              </div>
              <div className="mb-3 rounded-2xl border-2 border-site-line p-4">
                <p className="mb-1 text-xs font-semibold text-site-muted">Question 3/5</p>
                <p className="font-bold">Quel fleuve traverse Paris ?</p>
              </div>
              <div className="mb-4 grid grid-cols-2 gap-2 text-sm font-bold">
                <span className="rounded-xl border-2 border-site-green bg-site-green/10 px-3 py-2.5 text-center text-[#2BA51F]">La Seine</span>
                <span className="rounded-xl border-2 border-site-line px-3 py-2.5 text-center text-site-muted">La Loire</span>
              </div>
              <div className="flex items-center justify-center gap-2 rounded-2xl bg-site-green py-3 text-sm font-extrabold text-white shadow-[0_4px_0_#2BA51F]">
                <Zap className="h-4 w-4" />
                +42 points · réponse rapide
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Testimonials */}
      <section className="bg-white px-5 py-24 sm:px-6">
        <div className="mx-auto max-w-6xl">
          <SectionTitle kicker="Avis" title="Ils apprennent en duel" />
          <div className="grid gap-4 sm:grid-cols-3">
            {TESTIMONIALS.map((t) => (
              <figure key={t.name} className="rounded-3xl border-2 border-site-line bg-site-bg p-6">
                <div className="mb-4 flex gap-0.5">
                  {Array.from({ length: 5 }).map((_, i) => (
                    <Star key={i} className="h-4 w-4 fill-site-gold text-site-gold" />
                  ))}
                </div>
                <blockquote className="mb-5 text-[15px] leading-relaxed text-site-ink/80">&ldquo;{t.text}&rdquo;</blockquote>
                <figcaption className="text-sm font-extrabold">{t.name}</figcaption>
              </figure>
            ))}
          </div>
        </div>
      </section>

      {/* FAQ */}
      <section id="faq" className="scroll-mt-20 px-5 py-24 sm:px-6">
        <div className="mx-auto max-w-3xl">
          <SectionTitle kicker="FAQ" title="Questions fréquentes" />
          <div className="space-y-3">
            {FAQ.map((f) => (
              <FaqItem key={f.q} q={f.q} a={f.a} />
            ))}
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="px-5 pb-24 sm:px-6">
        <div className="relative mx-auto max-w-5xl overflow-hidden rounded-[2.5rem] bg-gradient-to-br from-site-orange to-site-pink px-6 py-14 text-center text-white sm:px-16">
          <img
            src="/site/mascot-celebrate.webp"
            alt=""
            loading="lazy"
            className="mx-auto mb-4 w-28 animate-float drop-shadow-2xl sm:w-36"
          />
          <h2 className="mb-3 font-display text-3xl font-extrabold tracking-tight sm:text-5xl">Prêt pour ton premier duel ?</h2>
          <p className="mx-auto mb-8 max-w-md text-lg text-white/90">
            Télécharge Minduel gratuitement et commence dès aujourd'hui.
          </p>
          <AppStoreButton size="lg" onDark />
        </div>
      </section>

      <Footer />

      {/* Sticky mobile download bar */}
      <div className="fixed inset-x-0 bottom-0 z-40 border-t border-site-line bg-white/95 px-4 pb-[max(env(safe-area-inset-bottom),12px)] pt-3 backdrop-blur-xl md:hidden">
        <div className="flex items-center gap-3">
          <img src="/site/app-icon.png" alt="" className="h-11 w-11 rounded-xl" />
          <div className="min-w-0 flex-1 leading-tight">
            <p className="truncate font-extrabold">Minduel</p>
            <p className="truncate text-xs text-site-muted">Gratuit sur l'App Store</p>
          </div>
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noreferrer"
            className="rounded-full bg-site-orange px-5 py-2.5 text-sm font-extrabold text-white shadow-[0_4px_0_#C24F00] active:translate-y-[2px] active:shadow-[0_2px_0_#C24F00]"
          >
            Obtenir
          </a>
        </div>
      </div>
    </div>
  );
};

export default Index;
