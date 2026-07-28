import { Loader2 } from "lucide-react";
import { useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";

import { useAuth } from "@/hooks/useAuth";

/** Landing route for the production OAuth redirect. */
const AuthCallback = () => {
  const { exchangeCode } = useAuth();
  const navigate = useNavigate();
  const ran = useRef<boolean>(false);

  useEffect(() => {
    if (ran.current) return;
    ran.current = true;
    const code = new URLSearchParams(window.location.search).get("code");
    if (!code) {
      navigate("/admin", { replace: true });
      return;
    }
    void exchangeCode(code).finally(() => navigate("/admin", { replace: true }));
  }, [exchangeCode, navigate]);

  return (
    <div className="grid min-h-screen place-items-center bg-[#070a12] text-white">
      <div className="flex items-center gap-3 text-sm text-white/55">
        <Loader2 className="h-5 w-5 animate-spin" />
        Connexion en cours…
      </div>
    </div>
  );
};

export default AuthCallback;
