
import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { useToast } from "@/hooks/use-toast";

interface Route {
  id: string;
  name: string;
  prefix: string;
  provider: string;
  rate: string;
  priority: number;
  status: string;
  quality: string;
  sipServer?: string;
  username?: string;
  password?: string;
  notes?: string;
}

interface RouteFormProps {
  onClose: () => void;
  onRouteCreated?: (route: Route) => void;
  onRouteUpdated?: (route: Route) => void;
  editingRoute?: Route | null;
}

const RouteForm = ({ onClose, onRouteCreated, onRouteUpdated, editingRoute }: RouteFormProps) => {
  const [formData, setFormData] = useState({
    name: "",
    prefix: "",
    provider: "",
    rate: "",
    priority: "1",
    status: "Active",
    quality: "Good",
    sipServer: "",
    username: "",
    password: "",
    notes: ""
  });
  const { toast } = useToast();

  useEffect(() => {
    if (editingRoute) {
      setFormData({
        name: editingRoute.name || "",
        prefix: editingRoute.prefix || "",
        provider: editingRoute.provider || "",
        rate: editingRoute.rate || "",
        priority: editingRoute.priority?.toString() || "1",
        status: editingRoute.status || "Active",
        quality: editingRoute.quality || "Good",
        sipServer: editingRoute.sipServer || "",
        username: editingRoute.username || "",
        password: editingRoute.password || "",
        notes: editingRoute.notes || ""
      });
    }
  }, [editingRoute]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!formData.name || !formData.prefix || !formData.provider || !formData.rate) {
      toast({
        title: "Validation Error",
        description: "Please fill in all required fields",
        variant: "destructive"
      });
      return;
    }

    const routeData: Route = {
      id: editingRoute?.id || `RT${String(Math.floor(Math.random() * 1000)).padStart(3, '0')}`,
      name: formData.name,
      prefix: formData.prefix,
      provider: formData.provider,
      rate: formData.rate,
      priority: parseInt(formData.priority),
      status: formData.status,
      quality: formData.quality,
      sipServer: formData.sipServer,
      username: formData.username,
      password: formData.password,
      notes: formData.notes
    };

    if (editingRoute) {
      onRouteUpdated?.(routeData);
      toast({
        title: "Route Updated",
        description: `Route ${formData.name} has been updated successfully`,
      });
    } else {
      onRouteCreated?.(routeData);
      toast({
        title: "Route Created",
        description: `Route ${formData.name} has been created successfully`,
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
          <CardTitle>{editingRoute ? 'Edit Route' : 'Add New Route'}</CardTitle>
          <CardDescription>
            {editingRoute ? 'Update route configuration' : 'Configure a new call route'}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="name">Route Name *</Label>
                <Input
                  id="name"
                  value={formData.name}
                  onChange={(e) => handleInputChange("name", e.target.value)}
                  placeholder="Premium Route USA"
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="prefix">Prefix *</Label>
                <Input
                  id="prefix"
                  value={formData.prefix}
                  onChange={(e) => handleInputChange("prefix", e.target.value)}
                  placeholder="1"
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="provider">Provider *</Label>
                <Input
                  id="provider"
                  value={formData.provider}
                  onChange={(e) => handleInputChange("provider", e.target.value)}
                  placeholder="Carrier A"
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="rate">Rate *</Label>
                <Input
                  id="rate"
                  value={formData.rate}
                  onChange={(e) => handleInputChange("rate", e.target.value)}
                  placeholder="$0.015"
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="priority">Priority</Label>
                <Select value={formData.priority} onValueChange={(value) => handleInputChange("priority", value)}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select priority" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="1">1 (Highest)</SelectItem>
                    <SelectItem value="2">2 (High)</SelectItem>
                    <SelectItem value="3">3 (Medium)</SelectItem>
                    <SelectItem value="4">4 (Low)</SelectItem>
                    <SelectItem value="5">5 (Lowest)</SelectItem>
                  </SelectContent>
                </Select>
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
                    <SelectItem value="Maintenance">Maintenance</SelectItem>
                    <SelectItem value="Inactive">Inactive</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="sipServer">SIP Server</Label>
                <Input
                  id="sipServer"
                  value={formData.sipServer}
                  onChange={(e) => handleInputChange("sipServer", e.target.value)}
                  placeholder="sip.carrier.com"
                />
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
            <div className="space-y-2">
              <Label htmlFor="notes">Notes</Label>
              <Textarea
                id="notes"
                value={formData.notes}
                onChange={(e) => handleInputChange("notes", e.target.value)}
                placeholder="Additional notes about this route"
                rows={3}
              />
            </div>
            <div className="flex justify-end space-x-2 pt-4">
              <Button type="button" variant="outline" onClick={onClose}>
                Cancel
              </Button>
              <Button type="submit" className="bg-blue-600 hover:bg-blue-700">
                {editingRoute ? 'Update Route' : 'Create Route'}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
};

export default RouteForm;
