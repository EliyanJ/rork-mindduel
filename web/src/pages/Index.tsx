import { useState } from "react";

import {
  Brain,
  Swords,
  Trophy,
  Flame,
  Repeat,
  Globe2,
  Users,
  Zap,
  Star,
  ChevronDown,
  Apple,
} from "lucide-react";

import Footer from "@/components/Footer";
import Navbar from "@/components/Navbar";

const DISCIPLINES = [
  { name: "Histoire", color: "bg-orange-500/15 text-orange-400" },
  { name: "Sciences", color: "bg-violet-500/15 text-violet-400" },
  { name: "Géographie", color: "bg-sky-500/15 text-sky-400" },
  { name: "Littérature", color: "bg-emerald-500/15 text-emerald-400" },
  { name: "Arts & Musique", color: "bg-pink-500/15 text-pink-400" },
  { name: "Nature & Animaux", color: "bg-lime-500/15 text-lime-400" },
  { name: "Tech & Espace", color: "bg-amber-500/15 text-amber-400" },
];

const FEATURES = [
  {
    icon: Brain,
    title: "Parcours de connaissances",
    description: "Progresse chapitre après chapitre à travers 7 disciplines variées, du QCM à l'anagramme.",
  },
  {
    icon: Repeat,
    title: "Répétition espacée",
    description: "Les notions apprises reviennent au bon moment pour s'ancrer durablement dans ta mémoire.",
  },
  {
    icon: Swords,
    title: "Duels classés en temps réel",
    description: "Affronte de vrais joueurs du monde entier sur les mêmes questions, au même moment.",
  },
  {
    icon: Globe2,
    title: "Classement ELO mondial",
    description: "Chaque duel fait évoluer ton score. Réponse juste et rapide = plus de points.",
  },
  {
    icon: Users,
    title: "Amis & comparaison",
    description: "Ajoute tes amis avec leur code et compare vos classements et vos progressions.",
  },
  {
    icon: Flame,
    title: "Séries & objectifs quotidiens",
    description: "Garde ta flamme allumée avec un objectif de révision quotidien qui te correspond.",
  },
];

const STEPS = [
  {
    number: "01",
    title: "Choisis tes thèmes",
    description: "Sélectionne les disciplines qui t'intéressent parmi 7 univers de culture générale.",
  },
  {
    number: "02",
    title: "Apprends à ton rythme",
    description: "Enchaîne les chapitres de 5 questions, révise avec la répétition espacée.",
  },
  {
    number: "03",
    title: "Défie le monde entier",
    description: "Lance-toi dans un duel classé et grimpe au classement ELO mondial.",
  },
];

const TESTIMONIALS = [
  {
    name: "Camille R.",
    text: "Le duel en temps réel change tout. J'apprends sans m'en rendre compte et je progresse dans le classement chaque semaine.",
  },
  {
    name: "Thomas B.",
    text: "La répétition espacée est bluffante, les questions que j'avais ratées reviennent pile au bon moment.",
  },
  {
    name: "Lina M.",
    text: "7 thèmes différents, jamais lassant. Les anagrammes et les textes à trous cassent la routine du QCM classique.",
  },
];

const FAQ = [
  {
    q: "Minduel est-elle gratuite ?",
    a: "Oui, tu peux apprendre et jouer gratuitement. Un abonnement Premium optionnel débloque du contenu et des fonctions supplémentaires, avec 3 jours d'essai gratuit.",
  },
  {
    q: "Comment fonctionnent les duels classés ?",
    a: "Tu es mis en relation avec un vrai joueur de ton niveau, vous répondez aux mêmes questions au même moment. Une bonne réponse rapide rapporte plus de points ELO qu'une réponse lente, une erreur ne pénalise pas ton classement.",
  },
  {
    q: "Sur quelles plateformes Minduel est disponible ?",
    a: "Minduel est disponible sur iPhone via l'App Store. Une version Android est à l'étude.",
  },
  {
    q: "Puis-je jouer sans connexion ?",
    a: "Tu peux apprendre et réviser en mode entraînement sans compte. Pour les duels en ligne et le classement mondial, une connexion Apple ou Google est nécessaire.",
  },
];

const FaqItem = ({ q, a }: { q: string; a: string }) => {
  const [open, setOpen] = useState<boolean>(false);
  return (
    <div className="overflow-hidden rounded-2xl border border-white/10 bg-white/[0.03]">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="flex w-full items-center justify-between gap-4 px-5 py-4 text-left"
      >
        <span className="text-sm font-semibold text-white sm:text-base">{q}</span>
        <ChevronDown className={`h-4 w-4 shrink-0 text-white/50 transition-transform ${open ? "rotate-180" : ""}`} />
      </button>
      {open && <p className="px-5 pb-4 text-sm leading-relaxed text-white/60">{a}</p>}
    </div>
  );
};

const Index = () => {
  return (
    <div className="min-h-screen bg-[#0b0f1a] text-white">
      <Navbar />

      {/* Hero */}
      <section className="relative overflow-hidden pt-40 pb-20 sm:pt-48">
        <div
          aria-hidden
          className="pointer-events-none absolute left-1/2 top-[-10%] h-[560px] w-[900px] -translate-x-1/2 rounded-full bg-gradient-to-br from-amber-500/20 via-orange-500/10 to-transparent blur-3xl"
        />
        <div className="relative mx-auto grid max-w-6xl gap-16 px-6 lg:grid-cols-[1.05fr_0.95fr] lg:items-center">
          <div className="text-center lg:text-left">
            <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-4 py-1.5 text-xs font-medium text-white/70">
              <Star className="h-3.5 w-3.5 fill-amber-400 text-amber-400" />
              Le quiz qui se joue en duel
            </div>
            <h1 className="text-4xl font-extrabold leading-[1.05] tracking-tight sm:text-6xl">
              Apprends. Révise.
              <br />
              <span className="bg-gradient-to-r from-amber-400 to-orange-500 bg-clip-text text-transparent">
                Affronte le monde.
              </span>
            </h1>
            <p className="mx-auto mt-6 max-w-xl text-lg leading-relaxed text-white/60 lg:mx-0">
              Minduel est le jeu de culture générale qui transforme chaque notion apprise en arme
              pour tes duels classés. Histoire, sciences, géographie, littérature, arts et plus :
              progresse à ton rythme, puis défie de vrais joueurs en temps réel.
            </p>

            <div id="telecharger" className="mt-9 flex flex-col items-center gap-4 lg:items-start">
              <a
                href="https://apps.apple.com"
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-3 rounded-2xl bg-white px-6 py-3.5 text-[#0b0f1a] shadow-xl shadow-black/30 transition hover:brightness-95 active:scale-[0.98]"
              >
                <Apple className="h-7 w-7 fill-[#0b0f1a]" />
                <span className="text-left leading-tight">
                  <span className="block text-[11px] text-black/60">Télécharger sur</span>
                  <span className="block text-lg font-bold -mt-0.5">App Store</span>
                </span>
              </a>
              <p className="text-xs text-white/40">Gratuit · Essai Premium de 3 jours offert</p>
            </div>

            <div className="mt-10 flex flex-wrap justify-center gap-2 lg:justify-start">
              {DISCIPLINES.map((d) => (
                <span key={d.name} className={`rounded-full px-3 py-1.5 text-xs font-medium ${d.color}`}>
                  {d.name}
                </span>
              ))}
            </div>
          </div>

          <div className="relative mx-auto flex w-full max-w-sm items-center justify-center lg:max-w-none">
            <div
              aria-hidden
              className="absolute -inset-8 rounded-[3rem] bg-gradient-to-br from-amber-500/10 to-orange-600/5 blur-2xl"
            />
            <div className="relative flex gap-5">
              <img
                src="/screenshot-home.png"
                alt="Parcours d'apprentissage Minduel"
                className="w-[190px] -rotate-3 rounded-[2rem] border border-white/10 shadow-2xl shadow-black/50 sm:w-[220px]"
              />
              <img
                src="/screenshot-3.png"
                alt="Duel en temps réel Minduel"
                className="mt-10 w-[190px] rotate-3 rounded-[2rem] border border-white/10 shadow-2xl shadow-black/50 sm:w-[220px]"
              />
            </div>
          </div>
        </div>
      </section>

      {/* Stats bar */}
      <section className="border-y border-white/10 bg-white/[0.02] py-8">
        <div className="mx-auto grid max-w-6xl grid-cols-2 gap-6 px-6 text-center sm:grid-cols-4">
          {[
            { value: "315+", label: "Questions" },
            { value: "7", label: "Disciplines" },
            { value: "63", label: "Chapitres" },
            { value: "1v1", label: "Duels en direct" },
          ].map((s) => (
            <div key={s.label}>
              <p className="text-2xl font-extrabold text-white sm:text-3xl">{s.value}</p>
              <p className="mt-1 text-xs uppercase tracking-wider text-white/40">{s.label}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Features */}
      <section id="fonctionnalites" className="px-6 py-24">
        <div className="mx-auto max-w-6xl">
          <div className="mx-auto mb-14 max-w-2xl text-center">
            <p className="mb-3 text-sm font-semibold uppercase tracking-wider text-amber-400">Fonctionnalités</p>
            <h2 className="text-3xl font-extrabold tracking-tight sm:text-4xl">
              Tout ce qu'il faut pour progresser
            </h2>
          </div>
          <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {FEATURES.map((f) => (
              <div
                key={f.title}
                className="group rounded-3xl border border-white/10 bg-white/[0.03] p-6 transition hover:border-amber-500/30 hover:bg-white/[0.05]"
              >
                <div className="mb-4 flex h-11 w-11 items-center justify-center rounded-2xl bg-gradient-to-br from-amber-400 to-orange-500">
                  <f.icon className="h-5 w-5 text-[#0b0f1a]" strokeWidth={2.5} />
                </div>
                <h3 className="mb-2 text-base font-bold text-white">{f.title}</h3>
                <p className="text-sm leading-relaxed text-white/55">{f.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Duels / How it works */}
      <section id="duels" className="relative overflow-hidden px-6 py-24">
        <div
          aria-hidden
          className="pointer-events-none absolute right-0 top-1/4 h-[400px] w-[400px] rounded-full bg-orange-500/10 blur-3xl"
        />
        <div className="relative mx-auto grid max-w-6xl gap-14 lg:grid-cols-2 lg:items-center">
          <div>
            <p className="mb-3 text-sm font-semibold uppercase tracking-wider text-amber-400">Duels classés</p>
            <h2 className="mb-6 text-3xl font-extrabold tracking-tight sm:text-4xl">
              Chaque victoire fait grimper ton ELO mondial
            </h2>
            <p className="mb-10 max-w-lg text-white/60">
              Un vrai joueur de ton niveau, les mêmes questions au même moment. Réponds vite et
              juste pour gagner le plus de points, ou entraîne-toi contre un bot avant de te lancer.
            </p>

            <div className="space-y-6">
              {STEPS.map((s) => (
                <div key={s.number} className="flex gap-5">
                  <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-amber-500/30 bg-amber-500/10 text-sm font-bold text-amber-400">
                    {s.number}
                  </span>
                  <div>
                    <h3 className="mb-1 font-bold text-white">{s.title}</h3>
                    <p className="text-sm text-white/55">{s.description}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="relative mx-auto w-full max-w-sm">
            <div className="rounded-3xl border border-white/10 bg-gradient-to-b from-[#131a2b] to-[#0b0f1a] p-6 shadow-2xl shadow-black/40">
              <div className="mb-5 flex items-center justify-between">
                <span className="text-xs font-semibold uppercase tracking-wider text-white/40">Duel classé</span>
                <Trophy className="h-4 w-4 text-amber-400" />
              </div>
              <div className="mb-6 flex items-center justify-between rounded-2xl bg-white/5 p-4">
                <div className="text-center">
                  <div className="mx-auto mb-2 flex h-12 w-12 items-center justify-center rounded-full bg-violet-500/20">
                    <Brain className="h-6 w-6 text-violet-400" />
                  </div>
                  <p className="text-xs font-medium text-white/70">Toi</p>
                  <p className="text-lg font-extrabold text-white">1 248</p>
                </div>
                <Swords className="h-6 w-6 text-amber-400" />
                <div className="text-center">
                  <div className="mx-auto mb-2 flex h-12 w-12 items-center justify-center rounded-full bg-red-500/20">
                    <Brain className="h-6 w-6 text-red-400" />
                  </div>
                  <p className="text-xs font-medium text-white/70">Adversaire</p>
                  <p className="text-lg font-extrabold text-white">1 231</p>
                </div>
              </div>
              <div className="mb-4 rounded-2xl border border-white/10 p-4">
                <p className="mb-1 text-xs text-white/40">Question 3/5</p>
                <p className="text-sm font-semibold text-white">
                  Quel fleuve traverse Paris ?
                </p>
              </div>
              <div className="flex items-center justify-center gap-2 rounded-2xl bg-emerald-500/10 py-3 text-sm font-bold text-emerald-400">
                <Zap className="h-4 w-4" />
                +42 points · réponse rapide
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Testimonials */}
      <section id="avis" className="px-6 py-24">
        <div className="mx-auto max-w-6xl">
          <div className="mx-auto mb-14 max-w-2xl text-center">
            <p className="mb-3 text-sm font-semibold uppercase tracking-wider text-amber-400">Avis</p>
            <h2 className="text-3xl font-extrabold tracking-tight sm:text-4xl">Ils apprennent en duel</h2>
          </div>
          <div className="grid gap-5 sm:grid-cols-3">
            {TESTIMONIALS.map((t) => (
              <div key={t.name} className="rounded-3xl border border-white/10 bg-white/[0.03] p-6">
                <div className="mb-4 flex gap-0.5">
                  {Array.from({ length: 5 }).map((_, i) => (
                    <Star key={i} className="h-4 w-4 fill-amber-400 text-amber-400" />
                  ))}
                </div>
                <p className="mb-5 text-sm leading-relaxed text-white/70">&ldquo;{t.text}&rdquo;</p>
                <p className="text-sm font-semibold text-white/90">{t.name}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* FAQ */}
      <section id="faq" className="px-6 py-24">
        <div className="mx-auto max-w-3xl">
          <div className="mx-auto mb-12 max-w-2xl text-center">
            <p className="mb-3 text-sm font-semibold uppercase tracking-wider text-amber-400">FAQ</p>
            <h2 className="text-3xl font-extrabold tracking-tight sm:text-4xl">Questions fréquentes</h2>
          </div>
          <div className="space-y-3">
            {FAQ.map((f) => (
              <FaqItem key={f.q} q={f.q} a={f.a} />
            ))}
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="px-6 pb-24">
        <div className="relative mx-auto max-w-5xl overflow-hidden rounded-[2.5rem] border border-white/10 bg-gradient-to-br from-amber-500/15 via-[#0b0f1a] to-orange-600/10 px-8 py-16 text-center sm:px-16">
          <div
            aria-hidden
            className="pointer-events-none absolute left-1/2 top-0 h-[300px] w-[500px] -translate-x-1/2 rounded-full bg-amber-500/20 blur-3xl"
          />
          <div className="relative">
            <h2 className="mb-4 text-3xl font-extrabold tracking-tight sm:text-4xl">
              Prêt pour ton premier duel ?
            </h2>
            <p className="mx-auto mb-8 max-w-md text-white/60">
              Télécharge Minduel gratuitement et commence ton parcours de culture générale dès
              aujourd'hui.
            </p>
            <a
              href="https://apps.apple.com"
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-3 rounded-2xl bg-white px-7 py-4 text-[#0b0f1a] shadow-xl shadow-black/30 transition hover:brightness-95 active:scale-[0.98]"
            >
              <Apple className="h-7 w-7 fill-[#0b0f1a]" />
              <span className="text-left leading-tight">
                <span className="block text-[11px] text-black/60">Télécharger sur</span>
                <span className="block text-lg font-bold -mt-0.5">App Store</span>
              </span>
            </a>
          </div>
        </div>
      </section>

      <Footer />
    </div>
  );
};

export default Index;
