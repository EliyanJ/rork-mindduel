import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";

import AdminLayout from "@/components/AdminLayout";
import { AdminAuthProvider } from "@/hooks/useAdminAuth";

import { Toaster as Sonner } from "@/components/ui/sonner";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";

import Index from "./pages/Index";
import Support from "./pages/Support";
import Privacy from "./pages/Privacy";
import Terms from "./pages/Terms";
import AuthCallback from "./pages/AuthCallback";
import NotFound from "./pages/NotFound";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <BrowserRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
        <AdminAuthProvider>
          <Routes>
            <Route path="/" element={<Index />} />
            <Route path="/support" element={<Support />} />
            <Route path="/privacy" element={<Privacy />} />
            <Route path="/terms" element={<Terms />} />
            <Route path="/auth/callback" element={<AuthCallback />} />
            {/* Every admin tool sits behind one sign-in and shares the same top
                nav. The tools themselves are rendered (always mounted) by
                AdminLayout — these routes only drive which one is visible, so
                a running generation/verification loop survives navigation. */}
            <Route element={<AdminLayout />}>
              <Route path="/admin" element={<Navigate to="/admin-review" replace />} />
              <Route path="/admin-generator" element={null} />
              <Route path="/admin-review" element={null} />
              <Route path="/admin-calibration" element={null} />
              <Route path="/admin-path" element={null} />
              <Route path="/admin-users" element={null} />
            </Route>
            {/* ADD ALL CUSTOM ROUTES ABOVE THE CATCH-ALL "*" ROUTE */}
            <Route path="*" element={<NotFound />} />
          </Routes>
        </AdminAuthProvider>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
