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

const Privacy = () => {
  return (
    <div className="min-h-screen bg-[#0b0f1a] text-white">
      <Navbar />
      <div className="mx-auto max-w-2xl px-6 pb-16 pt-32">
        <Link to="/" className="mb-8 inline-flex items-center gap-2 text-sm text-white/60 hover:text-white">
          <ArrowLeft className="h-4 w-4" />
          Retour
        </Link>

        <h1 className="mb-2 text-3xl font-bold">Politique de confidentialité</h1>
        <p className="mb-10 text-sm text-white/40">Dernière mise à jour : juillet 2026</p>

        <Section title="Qui nous sommes">
          <p>
            Minduel est une application de quiz et de duels en ligne. Cette page décrit les données
            que nous collectons lorsque tu utilises l'application et pourquoi. Pour toute question,
            contacte-nous à support@minduel.app.
          </p>
        </Section>

        <Section title="Données que nous collectons">
          <ul className="list-disc space-y-2 pl-5">
            <li>
              <span className="text-white">Compte</span> : si tu te connectes avec Google ou Apple,
              nous recevons ton identifiant, ton adresse email, ton nom et ta photo de profil
              (lorsqu'elle est fournie par Apple ou Google).
            </li>
            <li>
              <span className="text-white">Progression de jeu</span> : chapitres terminés, score,
              séries de réussite, éléments à réviser — stockés sur ton appareil et, pour les
              fonctions en ligne, sur nos serveurs.
            </li>
            <li>
              <span className="text-white">Duels en ligne et classement</span> : ton score ELO,
              l'historique de tes duels, ta liste d'amis et ton code ami, afin de proposer le
              matchmaking et le classement mondial.
            </li>
            <li>
              <span className="text-white">Données techniques</span> : informations minimales de
              connexion réseau nécessaires au fonctionnement des duels en temps réel.
            </li>
          </ul>
          <p>Nous ne collectons pas de données de localisation, de contacts ou de photos.</p>
        </Section>

        <Section title="Pourquoi nous utilisons ces données">
          <ul className="list-disc space-y-2 pl-5">
            <li>Faire fonctionner ton compte et sauvegarder ta progression entre appareils.</li>
            <li>Faire fonctionner le matchmaking, les duels en temps réel et le classement.</li>
            <li>Te permettre d'ajouter des amis et de suivre leurs scores.</li>
            <li>Assurer le support technique lorsque tu nous contactes.</li>
          </ul>
        </Section>

        <Section title="Partage avec des tiers">
          <p>
            Nous ne vendons pas tes données. L'authentification est traitée par les services
            d'authentification de Google et Apple (selon le fournisseur choisi). L'hébergement de
            notre backend (comptes, duels, classement) est assuré par Cloudflare. Ces prestataires
            traitent les données uniquement pour permettre le fonctionnement du service.
          </p>
        </Section>

        <Section title="Conservation et suppression">
          <p>
            Tes données de compte et de progression sont conservées tant que ton compte est actif.
            Tu peux demander la suppression de ton compte et de toutes les données associées
            (progression, amis, historique de duels) à tout moment en écrivant à
            support@minduel.app. Nous traitons ces demandes sous 30 jours.
          </p>
        </Section>

        <Section title="Tes droits">
          <p>
            Tu peux demander l'accès, la correction, l'export ou la suppression de tes données
            personnelles à tout moment via support@minduel.app.
          </p>
        </Section>

        <Section title="Enfants">
          <p>
            Minduel n'est pas destinée aux enfants de moins de 13 ans et nous ne collectons pas
            sciemment de données concernant des enfants de cet âge.
          </p>
        </Section>

        <Section title="Modifications de cette politique">
          <p>
            Nous pouvons mettre à jour cette politique de confidentialité. Les changements
            importants seront reflétés par la mise à jour de la date en haut de cette page.
          </p>
        </Section>

        <Section title="Contact">
          <p>Pour toute question sur cette politique : support@minduel.app</p>
        </Section>
      </div>
      <Footer />
    </div>
  );
};

export default Privacy;
