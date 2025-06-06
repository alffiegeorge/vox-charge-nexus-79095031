
import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { useToast } from "@/hooks/use-toast";

interface DID {
  number: string;
  customer: string;
  country: string;
  rate: string;
  status: string;
  type: string;
  customerId?: string;
  notes?: string;
}

interface DIDFormProps {
  onClose: () => void;
  onDIDCreated?: (did: DID) => void;
  onDIDUpdated?: (did: DID) => void;
  editingDID?: DID | null;
}

const DIDForm = ({ onClose, onDIDCreated, onDIDUpdated, editingDID }: DIDFormProps) => {
  const [formData, setFormData] = useState({
    number: "",
    customer: "",
    country: "",
    rate: "",
    type: "",
    status: "Available",
    customerId: "",
    notes: ""
  });
  const { toast } = useToast();

  useEffect(() => {
    if (editingDID) {
      setFormData({
        number: editingDID.number || "",
        customer: editingDID.customer || "",
        country: editingDID.country || "",
        rate: editingDID.rate || "",
        type: editingDID.type || "",
        status: editingDID.status || "Available",
        customerId: editingDID.customerId || "",
        notes: editingDID.notes || ""
      });
    }
  }, [editingDID]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!formData.number || !formData.country || !formData.rate || !formData.type) {
      toast({
        title: "Validation Error",
        description: "Please fill in all required fields",
        variant: "destructive"
      });
      return;
    }

    if (editingDID) {
      const updatedDID: DID = {
        ...editingDID,
        number: formData.number,
        customer: formData.customer || "Unassigned",
        country: formData.country,
        rate: formData.rate,
        type: formData.type,
        status: formData.status,
        customerId: formData.customerId,
        notes: formData.notes
      };

      onDIDUpdated?.(updatedDID);
      
      toast({
        title: "DID Updated",
        description: `DID ${formData.number} has been updated successfully`,
      });
    } else {
      const newDID: DID = {
        number: formData.number,
        customer: formData.customer || "Unassigned",
        country: formData.country,
        rate: formData.rate,
        type: formData.type,
        status: formData.status,
        customerId: formData.customerId,
        notes: formData.notes
      };

      onDIDCreated?.(newDID);
      
      toast({
        title: "DID Created",
        description: `DID ${formData.number} has been created successfully`,
      });
    }
    
    onClose();
  };

  const handleInputChange = (field: string, value: string) => {
    setFormData(prev => ({ ...prev, [field]: value }));
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <Card className="w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <CardHeader>
          <CardTitle>{editingDID ? 'Edit DID' : 'Add New DID'}</CardTitle>
          <CardDescription>
            {editingDID ? 'Update DID information' : 'Add a new Direct Inward Dialing number'}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="number">DID Number *</Label>
                <Input
                  id="number"
                  value={formData.number}
                  onChange={(e) => handleInputChange("number", e.target.value)}
                  placeholder="+1-555-0123"
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="country">Country *</Label>
                <Select value={formData.country} onValueChange={(value) => handleInputChange("country", value)}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select country" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="USA">USA</SelectItem>
                    <SelectItem value="UK">UK</SelectItem>
                    <SelectItem value="Germany">Germany</SelectItem>
                    <SelectItem value="France">France</SelectItem>
                    <SelectItem value="Canada">Canada</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="type">DID Type *</Label>
                <Select value={formData.type} onValueChange={(value) => handleInputChange("type", value)}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select type" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="Local">Local</SelectItem>
                    <SelectItem value="International">International</SelectItem>
                    <SelectItem value="Toll-Free">Toll-Free</SelectItem>
                    <SelectItem value="Mobile">Mobile</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="rate">Monthly Rate *</Label>
                <Input
                  id="rate"
                  value={formData.rate}
                  onChange={(e) => handleInputChange("rate", e.target.value)}
                  placeholder="$5.00"
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="customer">Assign to Customer</Label>
                <Input
                  id="customer"
                  value={formData.customer}
                  onChange={(e) => handleInputChange("customer", e.target.value)}
                  placeholder="Customer name or leave empty"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="status">Status</Label>
                <Select value={formData.status} onValueChange={(value) => handleInputChange("status", value)}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select status" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="Available">Available</SelectItem>
                    <SelectItem value="Active">Active</SelectItem>
                    <SelectItem value="Suspended">Suspended</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div className="space-y-2">
              <Label htmlFor="notes">Notes</Label>
              <Textarea
                id="notes"
                value={formData.notes}
                onChange={(e) => handleInputChange("notes", e.target.value)}
                placeholder="Additional notes about this DID"
                rows={3}
              />
            </div>
            <div className="flex justify-end space-x-2 pt-4">
              <Button type="button" variant="outline" onClick={onClose}>
                Cancel
              </Button>
              <Button type="submit" className="bg-blue-600 hover:bg-blue-700">
                {editingDID ? 'Update DID' : 'Create DID'}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
};

export default DIDForm;
