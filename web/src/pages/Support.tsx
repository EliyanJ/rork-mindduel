import { Link } from "react-router-dom";
import { ArrowLeft, Mail } from "lucide-react";

import Footer from "@/components/Footer";
import Navbar from "@/components/Navbar";

const Support = () => {
  return (
    <div className="min-h-screen bg-[#0b0f1a] text-white">
      <Navbar />
      <div className="mx-auto max-w-2xl px-6 pb-16 pt-32">
        <Link to="/" className="mb-8 inline-flex items-center gap-2 text-sm text-white/60 hover:text-white">
          <ArrowLeft className="h-4 w-4" />
          Retour
        </Link>

        <h1 className="mb-6 text-3xl font-bold">Support Minduel</h1>

        <p className="mb-6 text-white/70">
          Une question, un bug, un souci de compte ou de duel en ligne ? Nous te répondons par email.
        </p>

        <div className="mb-8 flex items-center gap-3 rounded-2xl border border-white/10 bg-white/5 p-5">
          <Mail className="h-5 w-5 text-amber-400" />
          <a href="mailto:support@minduel.app" className="text-lg font-medium underline decoration-white/30">
            support@minduel.app
          </a>
        </div>

        <h2 className="mb-3 mt-10 text-xl font-semibold">Avant de nous écrire, indique si possible :</h2>
        <ul className="mb-8 list-disc space-y-2 pl-5 text-white/70">
          <li>Le nom de l'app : Minduel</li>
          <li>La version de l'app (visible dans ton profil)</li>
          <li>Ton modèle d'iPhone et la version d'iOS</li>
          <li>L'email associé à ton compte, si tu es connecté</li>
          <li>Une capture d'écran ou une description du problème rencontré</li>
        </ul>

        <h2 className="mb-3 text-xl font-semibold">Compte et connexion</h2>
        <p className="mb-8 text-white/70">
          Minduel utilise la connexion Google ou Apple. Si tu n'arrives pas à te connecter, à
          retrouver ta progression, ou si tu veux supprimer ton compte et tes données (progression,
          amis, statistiques de duel), écris-nous à l'adresse ci-dessus — nous traitons les demandes
          de suppression sous 30 jours.
        </p>

        <h2 className="mb-3 text-xl font-semibold">Duels en ligne</h2>
        <p className="text-white/70">
          En cas de déconnexion pendant un duel classé, de score ELO incorrect, ou de comportement
          suspect d'un autre joueur, précise l'heure approximative du match dans ton message : cela
          nous aide à retrouver la partie concernée.
        </p>
      </div>
      <Footer />
    </div>
  );
};

export default Support;
