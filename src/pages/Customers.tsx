
import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { QrCode, Eye, EyeOff } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { apiClient } from "@/lib/api";
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

const Customers = () => {
  const { toast } = useToast();
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [editingCustomer, setEditingCustomer] = useState<Customer | null>(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [viewingQRCode, setViewingQRCode] = useState<Customer | null>(null);

  useEffect(() => {
    fetchCustomers();
  }, []);

  const fetchCustomers = async () => {
    try {
      console.log('Fetching customers from database...');
      const data = await apiClient.getCustomers() as any[];
      console.log('Customers data received:', data);
      
      // Transform the data to match our interface
      const transformedCustomers = data.map((customer: any) => ({
        id: customer.id,
        name: customer.name,
        email: customer.email,
        phone: customer.phone,
        company: customer.company,
        type: customer.type,
        balance: customer.balance ? `$${customer.balance.toFixed(2)}` : '$0.00',
        status: customer.status,
        creditLimit: customer.credit_limit ? `$${customer.credit_limit.toFixed(2)}` : undefined,
        address: customer.address,
        notes: customer.notes,
        createdAt: customer.created_at,
        qrCodeEnabled: customer.qr_code_enabled || false,
        qrCodeData: customer.qr_code_data || `voiceflow://login?token=${customer.id.toLowerCase()}${Math.random().toString(36).substring(2, 6)}&server=demo.voiceflow.com&expires=${Date.now() + (24 * 60 * 60 * 1000)}`
      }));
      
      setCustomers(transformedCustomers);
    } catch (error) {
      console.error('Error fetching customers:', error);
      toast({
        title: "Error",
        description: "Failed to load customers from database",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const handleCustomerCreated = (newCustomer: Customer) => {
    setCustomers(prev => [...prev, newCustomer]);
    fetchCustomers(); // Refresh from database
  };

  const handleCustomerUpdated = (updatedCustomer: Customer) => {
    setCustomers(prev => prev.map(customer => 
      customer.id === updatedCustomer.id ? updatedCustomer : customer
    ));
    setEditingCustomer(null);
    fetchCustomers(); // Refresh from database
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

  if (loading) {
    return (
      <div className="p-6">
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Customer Management</h1>
          <p className="text-gray-600">Loading customers from database...</p>
        </div>
        <Card>
          <CardHeader>
            <CardTitle>Loading...</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="animate-pulse space-y-4">
              {[1, 2, 3].map((i) => (
                <div key={i} className="h-16 bg-gray-200 rounded"></div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Customer Management</h1>
        <p className="text-gray-600">Manage customer accounts and configurations</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Customer Management</CardTitle>
          <CardDescription>
            Manage customer accounts and configurations ({customers.length} customers loaded from database)
          </CardDescription>
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
              <div className="flex space-x-2">
                <Button 
                  variant="outline"
                  onClick={fetchCustomers}
                >
                  Refresh
                </Button>
                <Button 
                  className="bg-blue-600 hover:bg-blue-700"
                  onClick={() => setShowCreateForm(true)}
                >
                  Add New Customer
                </Button>
              </div>
            </div>
            
            {filteredCustomers.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                <p>No customers found</p>
                {searchTerm && <p className="text-sm">Try adjusting your search terms</p>}
                {!searchTerm && customers.length === 0 && (
                  <p className="text-sm">Add your first customer to get started</p>
                )}
              </div>
            ) : (
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
                        <td className="p-4">
                          <span className={customer.balance.includes('-') ? 'text-red-600' : 'text-green-600'}>
                            {customer.balance}
                          </span>
                        </td>
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
            )}
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
