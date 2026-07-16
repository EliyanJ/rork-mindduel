import { Link } from "react-router-dom";
import { ArrowLeft } from "lucide-react";

import Footer from "@/components/Footer";
import Navbar from "@/components/Navbar";

const Section = ({ title, children }: { title: string; children: React.ReactNode }) => (
  <div className="mb-8">
    <h2 className="mb-3 text-xl font-semibold">{title}</h2>
    <div className="space-y-3 text-white/70">{children}</div>
  </div>
);

const Terms = () => {
  return (
    <div className="min-h-screen bg-[#0b0f1a] text-white">
      <Navbar />
      <div className="mx-auto max-w-2xl px-6 pb-16 pt-32">
        <Link to="/" className="mb-8 inline-flex items-center gap-2 text-sm text-white/60 hover:text-white">
          <ArrowLeft className="h-4 w-4" />
          Retour
        </Link>

        <h1 className="mb-2 text-3xl font-bold">Conditions d'utilisation</h1>
        <p className="mb-10 text-sm text-white/40">Dernière mise à jour : juillet 2026</p>

        <Section title="Acceptation des conditions">
          <p>
            En utilisant Minduel, tu acceptes les présentes conditions d'utilisation. Si tu n'es
            pas d'accord, merci de ne pas utiliser l'application.
          </p>
        </Section>

        <Section title="Licence d'utilisation">
          <p>
            Minduel t'accorde une licence personnelle, non exclusive et non transférable pour
            utiliser l'application sur tes appareils personnels, conformément aux règles de
            l'App Store.
          </p>
        </Section>

        <Section title="Compte utilisateur">
          <p>
            La connexion via Google ou Apple te permet de sauvegarder ta progression et de
            participer aux duels en ligne. Tu es responsable de la confidentialité de ton compte et
            des actions effectuées avec celui-ci.
          </p>
        </Section>

        <Section title="Règles d'utilisation">
          <ul className="list-disc space-y-2 pl-5">
            <li>Ne pas tricher, automatiser ou exploiter de bug pour fausser le classement ELO.</li>
            <li>Ne pas harceler ou insulter d'autres joueurs via les fonctions sociales (amis).</li>
            <li>Ne pas tenter de perturber le service, le matchmaking ou les serveurs de duel.</li>
          </ul>
        </Section>

        <Section title="Duels et classement">
          <p>
            Le classement ELO et le classement mondial reflètent les résultats des duels en temps
            réel. Nous pouvons ajuster, réinitialiser ou corriger un score en cas d'erreur technique
            ou de comportement contraire aux règles ci-dessus.
          </p>
        </Section>

        <Section title="Disponibilité du service">
          <p>
            Les fonctions en ligne (duels, classement, amis) dépendent d'une connexion internet et
            de nos serveurs. Nous faisons de notre mieux pour assurer la disponibilité du service
            mais ne pouvons garantir une disponibilité continue à 100 %.
          </p>
        </Section>

        <Section title="Résiliation">
          <p>
            Nous pouvons suspendre ou supprimer un compte en cas de non-respect de ces conditions.
            Tu peux également demander la suppression de ton compte à tout moment.
          </p>
        </Section>

        <Section title="Limitation de responsabilité">
          <p>
            Minduel est fournie "telle quelle", sans garantie d'aucune sorte. Dans la mesure permise
            par la loi, nous ne sommes pas responsables des dommages indirects liés à l'utilisation
            de l'application.
          </p>
        </Section>

        <Section title="Contact">
          <p>Pour toute question sur ces conditions : support@minduel.app</p>
        </Section>
      </div>
      <Footer />
    </div>
  );
};

export default Terms;
