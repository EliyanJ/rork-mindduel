import { useLocation } from "react-router-dom";

import AdminCalibration from "@/pages/AdminCalibration";
import AdminGenerator from "@/pages/AdminGenerator";
import AdminPath from "@/pages/AdminPath";
import AdminReview from "@/pages/AdminReview";

/**
 * Keeps every admin tool mounted at all times and only toggles visibility
 * based on the current route. This is what lets a long-running job (bulk
 * question generation, AI verification loop) keep running while the admin
 * moderates questions on another tab — navigating no longer unmounts the
 * page, so its in-flight loops, queues and logs survive intact.
 */
const AdminWorkspace = () => {
  const { pathname } = useLocation();

  return (
    <>
      <div className={pathname === "/admin-generator" ? "" : "hidden"}>
        <AdminGenerator />
      </div>
      <div className={pathname === "/admin-review" ? "" : "hidden"}>
        <AdminReview />
      </div>
      <div className={pathname === "/admin-calibration" ? "" : "hidden"}>
        <AdminCalibration />
      </div>
      <div className={pathname === "/admin-path" ? "" : "hidden"}>
        <AdminPath />
      </div>
    </>
  );
};

export default AdminWorkspace;
