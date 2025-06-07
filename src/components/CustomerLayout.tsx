import { Phone, BarChart3, CreditCard, Settings, LogOut, FileText } from "lucide-react";
import { Link, useLocation } from "react-router-dom";

interface CustomerLayoutProps {
  children: React.ReactNode;
}

const CustomerLayout = ({ children }: CustomerLayoutProps) => {
  const location = useLocation();

  const menuItems = [
    { icon: BarChart3, label: "Dashboard", path: "/customer" },
    { icon: Phone, label: "Call History", path: "/customer/calls" },
    { icon: CreditCard, label: "Billing", path: "/customer/billing" },
    { icon: FileText, label: "Invoices", path: "/customer/invoices" },
    { icon: Settings, label: "Settings", path: "/customer/settings" }
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
              <p className="text-sm text-gray-500">Customer Portal</p>
            </div>
          </div>
        </div>
        <nav className="p-4">
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

export default CustomerLayout;
