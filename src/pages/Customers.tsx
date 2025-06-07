
import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { QrCode, Eye, EyeOff } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import CustomerForm from "@/components/CustomerForm";

interface Customer {
  id: string;
  name: string;
  email: string;
  phone: string;
  company?: string;
  type: string;
  balance: string;
  status: string;
  creditLimit?: string;
  address?: string;
  notes?: string;
  createdAt?: string;
  qrCodeEnabled?: boolean;
  qrCodeData?: string;
}

const INITIAL_CUSTOMERS: Customer[] = [
  { 
    id: "C001", 
    name: "John Doe", 
    email: "john@example.com", 
    type: "Prepaid", 
    balance: "$125.50", 
    status: "Active", 
    phone: "+1-555-0123",
    qrCodeEnabled: true,
    qrCodeData: "voiceflow://login?token=john123&server=demo.voiceflow.com&expires=1735689600"
  },
  { 
    id: "C002", 
    name: "Jane Smith", 
    email: "jane@example.com", 
    type: "Postpaid", 
    balance: "$-45.20", 
    status: "Active", 
    phone: "+1-555-0456",
    qrCodeEnabled: true,
    qrCodeData: "voiceflow://login?token=jane456&server=demo.voiceflow.com&expires=1735689600"
  },
  { 
    id: "C003", 
    name: "Bob Johnson", 
    email: "bob@example.com", 
    type: "Prepaid", 
    balance: "$0.00", 
    status: "Suspended", 
    phone: "+1-555-0789",
    qrCodeEnabled: false
  },
  { 
    id: "C004", 
    name: "Alice Wilson", 
    email: "alice@example.com", 
    type: "Prepaid", 
    balance: "$89.75", 
    status: "Active", 
    phone: "+1-555-0321",
    qrCodeEnabled: true,
    qrCodeData: "voiceflow://login?token=alice321&server=demo.voiceflow.com&expires=1735689600"
  },
  { 
    id: "C005", 
    name: "Mike Davis", 
    email: "mike@example.com", 
    type: "Postpaid", 
    balance: "$-12.80", 
    status: "Active", 
    phone: "+1-555-0654",
    qrCodeEnabled: false
  }
];

const Customers = () => {
  const { toast } = useToast();
  const [customers, setCustomers] = useState<Customer[]>(INITIAL_CUSTOMERS);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [editingCustomer, setEditingCustomer] = useState<Customer | null>(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [viewingQRCode, setViewingQRCode] = useState<Customer | null>(null);

  const handleCustomerCreated = (newCustomer: Customer) => {
    setCustomers(prev => [...prev, newCustomer]);
  };

  const handleCustomerUpdated = (updatedCustomer: Customer) => {
    setCustomers(prev => prev.map(customer => 
      customer.id === updatedCustomer.id ? updatedCustomer : customer
    ));
    setEditingCustomer(null);
  };

  const handleEditCustomer = (customer: Customer) => {
    setEditingCustomer(customer);
  };

  const handleCloseForm = () => {
    setShowCreateForm(false);
    setEditingCustomer(null);
  };

  const handleViewQRCode = (customer: Customer) => {
    setViewingQRCode(customer);
  };

  const handleToggleQRCode = (customerId: string) => {
    setCustomers(prev => prev.map(customer => {
      if (customer.id === customerId) {
        const newQREnabled = !customer.qrCodeEnabled;
        const updatedCustomer = {
          ...customer,
          qrCodeEnabled: newQREnabled,
          qrCodeData: newQREnabled && !customer.qrCodeData 
            ? `voiceflow://login?token=${customerId.toLowerCase()}${Math.random().toString(36).substring(2, 6)}&server=demo.voiceflow.com&expires=${Date.now() + (24 * 60 * 60 * 1000)}`
            : customer.qrCodeData
        };
        
        toast({
          title: newQREnabled ? "QR Code Enabled" : "QR Code Disabled",
          description: `QR code access has been ${newQREnabled ? 'enabled' : 'disabled'} for ${customer.name}.`,
        });
        
        return updatedCustomer;
      }
      return customer;
    }));
  };

  const handleGenerateNewQRCode = (customerId: string) => {
    setCustomers(prev => prev.map(customer => {
      if (customer.id === customerId) {
        const newToken = Math.random().toString(36).substring(2, 15);
        const expiresAt = Date.now() + (24 * 60 * 60 * 1000);
        const newQRData = `voiceflow://login?token=${newToken}&server=demo.voiceflow.com&expires=${expiresAt}`;
        
        toast({
          title: "QR Code Regenerated",
          description: `New QR code generated for ${customer.name}.`,
        });
        
        return {
          ...customer,
          qrCodeData: newQRData
        };
      }
      return customer;
    }));
  };

  const filteredCustomers = customers.filter(customer =>
    customer.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    customer.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
    customer.id.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Customer Management</h1>
        <p className="text-gray-600">Manage customer accounts and configurations</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Customer Management</CardTitle>
          <CardDescription>Manage customer accounts and configurations</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <Input 
                placeholder="Search customers..." 
                className="max-w-sm" 
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
              <Button 
                className="bg-blue-600 hover:bg-blue-700"
                onClick={() => setShowCreateForm(true)}
              >
                Add New Customer
              </Button>
            </div>
            <div className="border rounded-lg">
              <table className="w-full">
                <thead className="border-b bg-gray-50">
                  <tr>
                    <th className="text-left p-4">Customer ID</th>
                    <th className="text-left p-4">Name</th>
                    <th className="text-left p-4">Email</th>
                    <th className="text-left p-4">Type</th>
                    <th className="text-left p-4">Balance</th>
                    <th className="text-left p-4">Status</th>
                    <th className="text-left p-4">QR Code</th>
                    <th className="text-left p-4">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredCustomers.map((customer, index) => (
                    <tr key={index} className="border-b">
                      <td className="p-4">{customer.id}</td>
                      <td className="p-4">{customer.name}</td>
                      <td className="p-4">{customer.email}</td>
                      <td className="p-4">{customer.type}</td>
                      <td className="p-4">{customer.balance}</td>
                      <td className="p-4">
                        <span className={`px-2 py-1 rounded-full text-xs ${
                          customer.status === "Active" ? "bg-green-100 text-green-800" : "bg-red-100 text-red-800"
                        }`}>
                          {customer.status}
                        </span>
                      </td>
                      <td className="p-4">
                        <div className="flex items-center space-x-2">
                          {customer.qrCodeEnabled ? (
                            <>
                              <Button
                                variant="outline"
                                size="sm"
                                onClick={() => handleViewQRCode(customer)}
                                className="flex items-center space-x-1"
                              >
                                <QrCode className="h-4 w-4" />
                                <span>View</span>
                              </Button>
                              <Button
                                variant="outline"
                                size="sm"
                                onClick={() => handleToggleQRCode(customer.id)}
                                className="flex items-center space-x-1"
                              >
                                <EyeOff className="h-4 w-4" />
                              </Button>
                            </>
                          ) : (
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => handleToggleQRCode(customer.id)}
                              className="flex items-center space-x-1"
                            >
                              <Eye className="h-4 w-4" />
                              <span>Enable QR</span>
                            </Button>
                          )}
                        </div>
                      </td>
                      <td className="p-4">
                        <Button 
                          variant="outline" 
                          size="sm"
                          onClick={() => handleEditCustomer(customer)}
                        >
                          Edit
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </CardContent>
      </Card>

      {(showCreateForm || editingCustomer) && (
        <CustomerForm
          onClose={handleCloseForm}
          onCustomerCreated={handleCustomerCreated}
          onCustomerUpdated={handleCustomerUpdated}
          editingCustomer={editingCustomer}
        />
      )}

      {viewingQRCode && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <Card className="w-96 max-w-md">
            <CardHeader>
              <CardTitle>QR Code for {viewingQRCode.name}</CardTitle>
              <CardDescription>Mobile app login QR code</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex flex-col items-center space-y-4">
                <div className="w-48 h-48 border-2 border-dashed border-gray-300 rounded-lg flex items-center justify-center bg-gray-50">
                  <div className="text-center">
                    <QrCode className="h-16 w-16 text-gray-400 mx-auto mb-2" />
                    <p className="text-sm text-gray-500">QR Code for Mobile Login</p>
                    <p className="text-xs text-gray-400 mt-1">Scan with VoiceFlow app</p>
                  </div>
                </div>
                {viewingQRCode.qrCodeData && (
                  <div className="text-xs text-gray-500 max-w-full break-all font-mono bg-gray-100 p-2 rounded">
                    {viewingQRCode.qrCodeData}
                  </div>
                )}
                <div className="flex space-x-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleGenerateNewQRCode(viewingQRCode.id)}
                  >
                    Regenerate
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setViewingQRCode(null)}
                  >
                    Close
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
};

export default Customers;
