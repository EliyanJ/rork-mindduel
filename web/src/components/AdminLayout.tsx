import { Loader2 } from "lucide-react";
import { Outlet } from "react-router-dom";

import AdminLogin from "@/components/AdminLogin";
import AdminTopNav from "@/components/AdminTopNav";
import { useAdminAuth } from "@/hooks/useAdminAuth";

/**
 * Guards every admin route behind a single sign-in, then renders the shared
 * navigation above the active tool.
 */
const AdminLayout = () => {
  const { session, isRestoring } = useAdminAuth();

  if (isRestoring) {
    return (
      <div className="grid min-h-screen place-items-center bg-[#070a12] text-white/40">
        <Loader2 className="h-6 w-6 animate-spin" />
      </div>
    );
  }

  if (!session) return <AdminLogin />;

  return (
    <div className="min-h-screen bg-[#070a12]">
      <AdminTopNav />
      <Outlet />
    </div>
  );
};

export default AdminLayout;
