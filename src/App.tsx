
import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import Index from "./pages/Index";
import NotFound from "./pages/NotFound";
import AdminLayout from "./components/AdminLayout";
import CustomerLayout from "./components/CustomerLayout";
import AdminDashboard from "./pages/AdminDashboard";
import CustomerDashboard from "./pages/CustomerDashboard";
import Customers from "./pages/Customers";
import DIDs from "./pages/DIDs";
import Trunks from "./pages/Trunks";
import Billing from "./pages/Billing";
import Rates from "./pages/Rates";
import Reports from "./pages/Reports";
import Settings from "./pages/Settings";
import CustomerCallHistory from "./pages/CustomerCallHistory";
import CustomerBilling from "./pages/CustomerBilling";
import CustomerSettings from "./pages/CustomerSettings";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Index />} />
          
          {/* Admin Routes */}
          <Route path="/admin" element={<AdminLayout><AdminDashboard /></AdminLayout>} />
          <Route path="/admin/customers" element={<AdminLayout><Customers /></AdminLayout>} />
          <Route path="/admin/dids" element={<AdminLayout><DIDs /></AdminLayout>} />
          <Route path="/admin/trunks" element={<AdminLayout><Trunks /></AdminLayout>} />
          <Route path="/admin/billing" element={<AdminLayout><Billing /></AdminLayout>} />
          <Route path="/admin/rates" element={<AdminLayout><Rates /></AdminLayout>} />
          <Route path="/admin/reports" element={<AdminLayout><Reports /></AdminLayout>} />
          <Route path="/admin/settings" element={<AdminLayout><Settings /></AdminLayout>} />
          
          {/* Customer Routes */}
          <Route path="/customer" element={<CustomerLayout><CustomerDashboard /></CustomerLayout>} />
          <Route path="/customer/calls" element={<CustomerLayout><CustomerCallHistory /></CustomerLayout>} />
          <Route path="/customer/billing" element={<CustomerLayout><CustomerBilling /></CustomerLayout>} />
          <Route path="/customer/settings" element={<CustomerLayout><CustomerSettings /></CustomerLayout>} />
          
          {/* Catch-all route */}
          <Route path="*" element={<NotFound />} />
        </Routes>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
