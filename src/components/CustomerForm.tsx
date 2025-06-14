import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { useToast } from "@/hooks/use-toast";
import { apiClient } from "@/lib/api";

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
}

interface CustomerFormProps {
  onClose: () => void;
  onCustomerCreated?: (customer: any) => void;
  onCustomerUpdated?: (customer: Customer) => void;
  editingCustomer?: Customer | null;
}

// Define the API response interface
interface CustomerApiResponse {
  id?: string;
  name?: string;
  email?: string;
  phone?: string;
  company?: string;
  type?: string;
  balance?: number;
  status?: string;
  credit_limit?: number;
  address?: string;
  notes?: string;
  created_at?: string;
}

const CustomerForm = ({ onClose, onCustomerCreated, onCustomerUpdated, editingCustomer }: CustomerFormProps) => {
  const [formData, setFormData] = useState({
    name: "",
    email: "",
    phone: "",
    company: "",
    type: "",
    creditLimit: "",
    address: "",
    notes: ""
  });
  const [loading, setLoading] = useState(false);
  const { toast } = useToast();

  useEffect(() => {
    if (editingCustomer) {
      setFormData({
        name: editingCustomer.name || "",
        email: editingCustomer.email || "",
        phone: editingCustomer.phone || "",
        company: editingCustomer.company || "",
        type: editingCustomer.type || "",
        creditLimit: editingCustomer.creditLimit?.replace('$', '') || "",
        address: editingCustomer.address || "",
        notes: editingCustomer.notes || ""
      });
    }
  }, [editingCustomer]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!formData.name || !formData.email || !formData.phone || !formData.type) {
      toast({
        title: "Validation Error",
        description: "Please fill in all required fields",
        variant: "destructive"
      });
      return;
    }

    setLoading(true);

    try {
      if (editingCustomer) {
        // Update existing customer
        const updateData = {
          name: formData.name,
          email: formData.email,
          phone: formData.phone,
          company: formData.company,
          type: formData.type,
          credit_limit: formData.creditLimit ? parseFloat(formData.creditLimit.replace('$', '')) || 0 : 0,
          address: formData.address,
          notes: formData.notes
        };

        console.log('=== CUSTOMER UPDATE START ===');
        console.log('Updating customer with data:', updateData);
        console.log('Customer ID:', editingCustomer.id);
        
        try {
          const response = await apiClient.updateCustomer(editingCustomer.id, updateData) as CustomerApiResponse;
          console.log('=== API RESPONSE RECEIVED ===');
          console.log('Raw API response:', response);
          console.log('Response type:', typeof response);
          console.log('Response keys:', Object.keys(response || {}));
          
          // Log each field individually
          console.log('Response fields:');
          console.log('- id:', response.id, typeof response.id);
          console.log('- name:', response.name, typeof response.name);
          console.log('- email:', response.email, typeof response.email);
          console.log('- phone:', response.phone, typeof response.phone);
          console.log('- company:', response.company, typeof response.company);
          console.log('- type:', response.type, typeof response.type);
          console.log('- balance:', response.balance, typeof response.balance);
          console.log('- status:', response.status, typeof response.status);
          console.log('- credit_limit:', response.credit_limit, typeof response.credit_limit);
          console.log('- address:', response.address, typeof response.address);
          console.log('- notes:', response.notes, typeof response.notes);
          console.log('- created_at:', response.created_at, typeof response.created_at);
          
          console.log('=== STARTING TRANSFORMATION ===');
          
          // Create the updated customer object step by step
          const updatedCustomer: Customer = {
            id: response.id || editingCustomer.id,
            name: response.name || formData.name,
            email: response.email || formData.email,
            phone: response.phone || formData.phone,
            company: response.company || formData.company,
            type: response.type || formData.type,
            balance: (() => {
              console.log('Processing balance:', response.balance, typeof response.balance);
              try {
                if (response.balance !== undefined && response.balance !== null) {
                  if (typeof response.balance === 'number') {
                    return `$${response.balance.toFixed(2)}`;
                  } else if (typeof response.balance === 'string') {
                    const parsed = parseFloat(response.balance);
                    if (!isNaN(parsed)) {
                      return `$${parsed.toFixed(2)}`;
                    }
                  }
                }
                return editingCustomer.balance;
              } catch (balanceError) {
                console.error('Error processing balance:', balanceError);
                return editingCustomer.balance;
              }
            })(),
            status: response.status || editingCustomer.status,
            creditLimit: (() => {
              console.log('Processing credit_limit:', response.credit_limit, typeof response.credit_limit);
              try {
                if (response.credit_limit !== undefined && response.credit_limit !== null) {
                  if (typeof response.credit_limit === 'number' && response.credit_limit > 0) {
                    return `$${response.credit_limit.toFixed(2)}`;
                  } else if (typeof response.credit_limit === 'string') {
                    const parsed = parseFloat(response.credit_limit);
                    if (!isNaN(parsed) && parsed > 0) {
                      return `$${parsed.toFixed(2)}`;
                    }
                  }
                }
                return undefined;
              } catch (creditError) {
                console.error('Error processing credit_limit:', creditError);
                return undefined;
              }
            })(),
            address: response.address || formData.address,
            notes: response.notes || formData.notes,
            createdAt: response.created_at || editingCustomer.createdAt
          };
          
          console.log('=== TRANSFORMATION COMPLETE ===');
          console.log('Final transformed customer:', updatedCustomer);
          
          // Call the callback
          console.log('=== CALLING CALLBACK ===');
          if (onCustomerUpdated) {
            onCustomerUpdated(updatedCustomer);
            console.log('Callback called successfully');
          }
          
          // Show success toast
          console.log('=== SHOWING SUCCESS TOAST ===');
          toast({
            title: "Customer Updated",
            description: `Customer ${formData.name} has been updated successfully`,
          });
          
          console.log('=== UPDATE PROCESS COMPLETE ===');
        } catch (apiError) {
          console.error('=== API CALL ERROR ===');
          console.error('API Error:', apiError);
          throw apiError;
        }
      } else {
        // Create new customer
        const newCustomerData = {
          name: formData.name,
          email: formData.email,
          phone: formData.phone,
          company: formData.company,
          type: formData.type,
          balance: 0,
          status: "Active",
          credit_limit: formData.creditLimit ? parseFloat(formData.creditLimit.replace('$', '')) || 0 : 0,
          address: formData.address,
          notes: formData.notes
        };

        console.log('Creating customer with data:', newCustomerData);
        const createdCustomer = await apiClient.createCustomer(newCustomerData);
        
        onCustomerCreated?.(createdCustomer);
        
        toast({
          title: "Customer Created",
          description: `Customer ${formData.name} has been created successfully`,
        });
      }
      
      console.log('=== CLOSING FORM ===');
      onClose();
    } catch (error) {
      console.error('=== FINAL ERROR HANDLER ===');
      console.error('Error saving customer:', error);
      console.error('Error type:', typeof error);
      console.error('Error constructor:', error?.constructor?.name);
      console.error('Error message:', error instanceof Error ? error.message : 'Unknown error');
      console.error('Error stack:', error instanceof Error ? error.stack : 'No stack');
      console.error('Full error object:', error);
      
      toast({
        title: "Error",
        description: `Failed to ${editingCustomer ? 'update' : 'create'} customer: ${error instanceof Error ? error.message : 'Unknown error'}`,
        variant: "destructive"
      });
    } finally {
      console.log('=== SETTING LOADING FALSE ===');
      setLoading(false);
    }
  };

  const handleInputChange = (field: string, value: string) => {
    setFormData(prev => ({ ...prev, [field]: value }));
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <Card className="w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <CardHeader>
          <CardTitle>{editingCustomer ? 'Edit Customer' : 'Create New Customer'}</CardTitle>
          <CardDescription>
            {editingCustomer ? 'Update customer information' : 'Add a new customer to the system'}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="name">Full Name *</Label>
                <Input
                  id="name"
                  value={formData.name}
                  onChange={(e) => handleInputChange("name", e.target.value)}
                  placeholder="Enter customer name"
                  required
                  disabled={loading}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="email">Email *</Label>
                <Input
                  id="email"
                  type="email"
                  value={formData.email}
                  onChange={(e) => handleInputChange("email", e.target.value)}
                  placeholder="Enter email address"
                  required
                  disabled={loading}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="phone">Phone Number *</Label>
                <Input
                  id="phone"
                  value={formData.phone}
                  onChange={(e) => handleInputChange("phone", e.target.value)}
                  placeholder="+1-555-0123"
                  required
                  disabled={loading}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="company">Company</Label>
                <Input
                  id="company"
                  value={formData.company}
                  onChange={(e) => handleInputChange("company", e.target.value)}
                  placeholder="Enter company name"
                  disabled={loading}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="type">Account Type *</Label>
                <Select value={formData.type} onValueChange={(value) => handleInputChange("type", value)} disabled={loading}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select account type" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="Prepaid">Prepaid</SelectItem>
                    <SelectItem value="Postpaid">Postpaid</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="creditLimit">Credit Limit</Label>
                <Input
                  id="creditLimit"
                  value={formData.creditLimit}
                  onChange={(e) => handleInputChange("creditLimit", e.target.value)}
                  placeholder="0.00"
                  disabled={loading}
                />
              </div>
            </div>
            <div className="space-y-2">
              <Label htmlFor="address">Address</Label>
              <Textarea
                id="address"
                value={formData.address}
                onChange={(e) => handleInputChange("address", e.target.value)}
                placeholder="Enter customer address"
                rows={2}
                disabled={loading}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="notes">Notes</Label>
              <Textarea
                id="notes"
                value={formData.notes}
                onChange={(e) => handleInputChange("notes", e.target.value)}
                placeholder="Additional notes about the customer"
                rows={3}
                disabled={loading}
              />
            </div>
            <div className="flex justify-end space-x-2 pt-4">
              <Button type="button" variant="outline" onClick={onClose} disabled={loading}>
                Cancel
              </Button>
              <Button type="submit" className="bg-blue-600 hover:bg-blue-700" disabled={loading}>
                {loading ? 'Saving...' : (editingCustomer ? 'Update Customer' : 'Create Customer')}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
};

export default CustomerForm;
