
import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { useToast } from "@/hooks/use-toast";

interface Trunk {
  name: string;
  provider: string;
  sipServer: string;
  maxChannels: number;
  status: string;
  quality: string;
  username?: string;
  password?: string;
  port?: string;
  notes?: string;
}

interface TrunkFormProps {
  onClose: () => void;
  onTrunkCreated?: (trunk: Trunk) => void;
  onTrunkUpdated?: (trunk: Trunk) => void;
  editingTrunk?: Trunk | null;
}

const TrunkForm = ({ onClose, onTrunkCreated, onTrunkUpdated, editingTrunk }: TrunkFormProps) => {
  const [formData, setFormData] = useState({
    name: "",
    provider: "",
    sipServer: "",
    maxChannels: "",
    status: "Active",
    quality: "Good",
    username: "",
    password: "",
    port: "5060",
    notes: ""
  });
  const { toast } = useToast();

  useEffect(() => {
    if (editingTrunk) {
      setFormData({
        name: editingTrunk.name || "",
        provider: editingTrunk.provider || "",
        sipServer: editingTrunk.sipServer || "",
        maxChannels: editingTrunk.maxChannels?.toString() || "",
        status: editingTrunk.status || "Active",
        quality: editingTrunk.quality || "Good",
        username: editingTrunk.username || "",
        password: editingTrunk.password || "",
        port: editingTrunk.port || "5060",
        notes: editingTrunk.notes || ""
      });
    }
  }, [editingTrunk]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!formData.name || !formData.provider || !formData.sipServer || !formData.maxChannels) {
      toast({
        title: "Validation Error",
        description: "Please fill in all required fields",
        variant: "destructive"
      });
      return;
    }

    const trunkData: Trunk = {
      name: formData.name,
      provider: formData.provider,
      sipServer: formData.sipServer,
      maxChannels: parseInt(formData.maxChannels),
      status: formData.status,
      quality: formData.quality,
      username: formData.username,
      password: formData.password,
      port: formData.port,
      notes: formData.notes
    };

    if (editingTrunk) {
      onTrunkUpdated?.(trunkData);
      toast({
        title: "Trunk Updated",
        description: `Trunk ${formData.name} has been updated successfully`,
      });
    } else {
      onTrunkCreated?.(trunkData);
      toast({
        title: "Trunk Created",
        description: `Trunk ${formData.name} has been created successfully`,
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
          <CardTitle>{editingTrunk ? 'Edit Trunk' : 'Add New Trunk'}</CardTitle>
          <CardDescription>
            {editingTrunk ? 'Update trunk configuration' : 'Configure a new SIP trunk connection'}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="name">Trunk Name *</Label>
                <Input
                  id="name"
                  value={formData.name}
                  onChange={(e) => handleInputChange("name", e.target.value)}
                  placeholder="Primary SIP Trunk"
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="provider">Provider *</Label>
                <Input
                  id="provider"
                  value={formData.provider}
                  onChange={(e) => handleInputChange("provider", e.target.value)}
                  placeholder="VoIP Provider A"
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="sipServer">SIP Server *</Label>
                <Input
                  id="sipServer"
                  value={formData.sipServer}
                  onChange={(e) => handleInputChange("sipServer", e.target.value)}
                  placeholder="sip.provider.com"
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="port">Port</Label>
                <Input
                  id="port"
                  value={formData.port}
                  onChange={(e) => handleInputChange("port", e.target.value)}
                  placeholder="5060"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="maxChannels">Max Channels *</Label>
                <Input
                  id="maxChannels"
                  type="number"
                  value={formData.maxChannels}
                  onChange={(e) => handleInputChange("maxChannels", e.target.value)}
                  placeholder="30"
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="status">Status</Label>
                <Select value={formData.status} onValueChange={(value) => handleInputChange("status", value)}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select status" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="Active">Active</SelectItem>
                    <SelectItem value="Standby">Standby</SelectItem>
                    <SelectItem value="Inactive">Inactive</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="username">Username</Label>
                <Input
                  id="username"
                  value={formData.username}
                  onChange={(e) => handleInputChange("username", e.target.value)}
                  placeholder="SIP username"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="password">Password</Label>
                <Input
                  id="password"
                  type="password"
                  value={formData.password}
                  onChange={(e) => handleInputChange("password", e.target.value)}
                  placeholder="SIP password"
                />
              </div>
            </div>
            <div className="space-y-2">
              <Label htmlFor="quality">Quality Rating</Label>
              <Select value={formData.quality} onValueChange={(value) => handleInputChange("quality", value)}>
                <SelectTrigger>
                  <SelectValue placeholder="Select quality" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="Excellent">Excellent</SelectItem>
                  <SelectItem value="Good">Good</SelectItem>
                  <SelectItem value="Fair">Fair</SelectItem>
                  <SelectItem value="Poor">Poor</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="notes">Notes</Label>
              <Textarea
                id="notes"
                value={formData.notes}
                onChange={(e) => handleInputChange("notes", e.target.value)}
                placeholder="Additional notes about this trunk"
                rows={3}
              />
            </div>
            <div className="flex justify-end space-x-2 pt-4">
              <Button type="button" variant="outline" onClick={onClose}>
                Cancel
              </Button>
              <Button type="submit" className="bg-blue-600 hover:bg-blue-700">
                {editingTrunk ? 'Update Trunk' : 'Create Trunk'}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
};

export default TrunkForm;
