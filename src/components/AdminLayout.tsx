
import { Phone, BarChart3, Users, Building2, CreditCard, Settings, FileText, LogOut, Route, Monitor, MessageSquare, Shield, Activity, Users2 } from "lucide-react";
import { Link, useLocation } from "react-router-dom";

interface AdminLayoutProps {
  children: React.ReactNode;
}

const AdminLayout = ({ children }: AdminLayoutProps) => {
  const location = useLocation();

  const menuItems = [
    { icon: BarChart3, label: "Dashboard", path: "/admin" },
    { icon: Users, label: "Customers", path: "/admin/customers" },
    { icon: Phone, label: "DID Management", path: "/admin/dids" },
    { icon: Building2, label: "Trunks", path: "/admin/trunks" },
    { icon: Route, label: "Route Management", path: "/admin/routes" },
    { icon: CreditCard, label: "Billing", path: "/admin/billing" },
    { icon: FileText, label: "Invoices", path: "/admin/invoices" },
    { icon: BarChart3, label: "Rates", path: "/admin/rates" },
    { icon: Activity, label: "Call Records", path: "/admin/cdr" },
    { icon: Monitor, label: "Quality Monitor", path: "/admin/quality" },
    { icon: MessageSquare, label: "SMS Management", path: "/admin/sms" },
    { icon: Users2, label: "Number Porting", path: "/admin/porting" },
    { icon: FileText, label: "Reports", path: "/admin/reports" },
    { icon: Shield, label: "Support Tickets", path: "/admin/tickets" },
    { icon: FileText, label: "Audit Logs", path: "/admin/audit" },
    { icon: Settings, label: "Settings", path: "/admin/settings" }
  ];

  const handleLogout = () => {
    window.location.href = "/";
  };

  return (
    <div className="flex h-screen bg-gray-100">
      <div className="w-64 bg-white shadow-lg">
        <div className="p-6 border-b">
          <div className="flex items-center space-x-2">
            <Phone className="h-8 w-8 text-blue-600" />
            <div>
              <h2 className="font-bold text-gray-900">iBilling</h2>
              <p className="text-sm text-gray-500">Admin Panel</p>
            </div>
          </div>
        </div>
        <nav className="p-4 overflow-y-auto max-h-[calc(100vh-120px)]">
          {menuItems.map((item, index) => (
            <Link
              key={index}
              to={item.path}
              className={`w-full flex items-center space-x-3 px-4 py-3 rounded-lg mb-2 transition-colors ${
                location.pathname === item.path
                  ? "bg-blue-600 text-white" 
                  : "text-gray-600 hover:bg-gray-100"
              }`}
            >
              <item.icon className="h-5 w-5" />
              <span>{item.label}</span>
            </Link>
          ))}
          <button
            onClick={handleLogout}
            className="w-full flex items-center space-x-3 px-4 py-3 rounded-lg mb-2 transition-colors text-red-600 hover:bg-red-50"
          >
            <LogOut className="h-5 w-5" />
            <span>Logout</span>
          </button>
        </nav>
      </div>
      <main className="flex-1 overflow-y-auto">
        {children}
      </main>
    </div>
  );
};

export default AdminLayout;
