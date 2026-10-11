import { Link } from "react-router-dom";

const NotFound = () => {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-site-bg px-6 text-center font-body text-site-ink">
      <img src="/site/mascot-wink.webp" alt="" className="mb-6 w-36 animate-float" />
      <h1 className="mb-2 font-display text-5xl font-extrabold">404</h1>
      <p className="mb-8 text-lg text-site-muted">Oups, cette page n'existe pas.</p>
      <Link
        to="/"
        className="rounded-2xl bg-site-orange px-6 py-3.5 font-extrabold text-white shadow-[0_5px_0_#C24F00] active:translate-y-[3px] active:shadow-[0_2px_0_#C24F00]"
      >
        Retour à l'accueil
      </Link>
    </div>
  );
};

export default NotFound;
