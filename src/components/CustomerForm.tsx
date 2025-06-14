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

        console.log('Updating customer with data:', updateData);
        
        const response = await apiClient.updateCustomer(editingCustomer.id, updateData) as CustomerApiResponse;
        console.log('API Response received:', response);
        
        // Create the updated customer object with proper type checking
        const updatedCustomer: Customer = {
          id: response.id || editingCustomer.id,
          name: response.name || formData.name,
          email: response.email || formData.email,
          phone: response.phone || formData.phone,
          company: response.company || formData.company,
          type: response.type || formData.type,
          balance: (() => {
            if (response.balance !== undefined && response.balance !== null) {
              const balanceNum = typeof response.balance === 'number' ? response.balance : parseFloat(String(response.balance));
              if (!isNaN(balanceNum)) {
                return `$${balanceNum.toFixed(2)}`;
              }
            }
            return editingCustomer.balance;
          })(),
          status: response.status || editingCustomer.status,
          creditLimit: (() => {
            // Check if credit_limit exists in response and is a valid number
            if (response.credit_limit !== undefined && response.credit_limit !== null) {
              const creditNum = typeof response.credit_limit === 'number' ? response.credit_limit : parseFloat(String(response.credit_limit));
              if (!isNaN(creditNum) && creditNum > 0) {
                return `$${creditNum.toFixed(2)}`;
              }
            }
            // If no valid credit_limit in response, check if we have form data
            if (formData.creditLimit) {
              const formCreditNum = parseFloat(formData.creditLimit.replace('$', ''));
              if (!isNaN(formCreditNum) && formCreditNum > 0) {
                return `$${formCreditNum.toFixed(2)}`;
              }
            }
            // Fall back to existing customer credit limit
            return editingCustomer.creditLimit;
          })(),
          address: response.address || formData.address,
          notes: response.notes || formData.notes,
          createdAt: response.created_at || editingCustomer.createdAt
        };
        
        console.log('Final transformed customer:', updatedCustomer);
        
        if (onCustomerUpdated) {
          onCustomerUpdated(updatedCustomer);
        }
        
        toast({
          title: "Customer Updated",
          description: `Customer ${formData.name} has been updated successfully`,
        });
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
      
      onClose();
    } catch (error) {
      console.error('Error saving customer:', error);
      
      toast({
        title: "Error",
        description: `Failed to ${editingCustomer ? 'update' : 'create'} customer: ${error instanceof Error ? error.message : 'Unknown error'}`,
        variant: "destructive"
      });
    } finally {
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
