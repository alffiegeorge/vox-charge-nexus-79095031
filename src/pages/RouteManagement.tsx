
import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { useToast } from "@/hooks/use-toast";
import RouteForm from "@/components/RouteForm";

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

const INITIAL_ROUTES: Route[] = [
  { id: "RT001", name: "Premium Route USA", prefix: "1", provider: "Carrier A", rate: "$0.015", priority: 1, status: "Active", quality: "98.5%" },
  { id: "RT002", name: "Standard Route USA", prefix: "1", provider: "Carrier B", rate: "$0.022", priority: 2, status: "Active", quality: "96.2%" },
  { id: "RT003", name: "UK Mobile Route", prefix: "447", provider: "Carrier C", rate: "$0.125", priority: 1, status: "Active", quality: "97.8%" },
  { id: "RT004", name: "Germany Route", prefix: "49", provider: "Carrier D", rate: "$0.085", priority: 1, status: "Maintenance", quality: "95.1%" }
];

const RouteManagement = () => {
  const [routes, setRoutes] = useState<Route[]>(INITIAL_ROUTES);
  const [showForm, setShowForm] = useState(false);
  const [editingRoute, setEditingRoute] = useState<Route | null>(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [testingRoutes, setTestingRoutes] = useState(false);
  const { toast } = useToast();

  const filteredRoutes = routes.filter(route =>
    route.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    route.provider.toLowerCase().includes(searchTerm.toLowerCase()) ||
    route.prefix.includes(searchTerm)
  );

  const handleAddRoute = () => {
    setEditingRoute(null);
    setShowForm(true);
  };

  const handleEditRoute = (route: Route) => {
    setEditingRoute(route);
    setShowForm(true);
  };

  const handleRouteCreated = (newRoute: Route) => {
    setRoutes(prev => [...prev, newRoute]);
  };

  const handleRouteUpdated = (updatedRoute: Route) => {
    setRoutes(prev => prev.map(route => 
      route.id === editingRoute?.id ? updatedRoute : route
    ));
  };

  const handleTestRoutes = async () => {
    setTestingRoutes(true);
    
    // Simulate route testing
    setTimeout(() => {
      setTestingRoutes(false);
      toast({
        title: "Route Test Complete",
        description: "All active routes tested successfully. Check quality metrics for details.",
      });
    }, 3000);

    toast({
      title: "Testing Routes",
      description: "Testing all active routes for connectivity and quality...",
    });
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case "Active": return "default";
      case "Standby": return "secondary";
      case "Maintenance": return "outline";
      case "Inactive": return "destructive";
      default: return "secondary";
    }
  };

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Route Management</h1>
        <p className="text-gray-600">Manage call routing, least cost routing, and failover configurations</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle>Active Routes</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-600">
              {routes.filter(route => route.status === "Active").length}
            </div>
            <p className="text-sm text-gray-600">Routes operational</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Average Quality</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-blue-600">97.2%</div>
            <p className="text-sm text-gray-600">Call completion rate</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Cost Savings</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-purple-600">$2,340</div>
            <p className="text-sm text-gray-600">This month via LCR</p>
          </CardContent>
        </Card>
      </div>

      <Card className="mb-6">
        <CardHeader>
          <CardTitle>Route Configuration</CardTitle>
          <CardDescription>Configure and manage call routes</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <Input
                placeholder="Search routes..."
                className="max-w-sm"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
              <div className="flex space-x-2">
                <Button
                  variant="outline"
                  onClick={handleTestRoutes}
                  disabled={testingRoutes}
                >
                  {testingRoutes ? "Testing..." : "Test Routes"}
                </Button>
                <Button className="bg-blue-600 hover:bg-blue-700" onClick={handleAddRoute}>
                  Add Route
                </Button>
              </div>
            </div>
            <div className="border rounded-lg">
              <table className="w-full">
                <thead className="border-b bg-gray-50">
                  <tr>
                    <th className="text-left p-4">Route ID</th>
                    <th className="text-left p-4">Name</th>
                    <th className="text-left p-4">Prefix</th>
                    <th className="text-left p-4">Provider</th>
                    <th className="text-left p-4">Rate</th>
                    <th className="text-left p-4">Priority</th>
                    <th className="text-left p-4">Quality</th>
                    <th className="text-left p-4">Status</th>
                    <th className="text-left p-4">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredRoutes.map((route, index) => (
                    <tr key={index} className="border-b">
                      <td className="p-4 font-mono">{route.id}</td>
                      <td className="p-4">{route.name}</td>
                      <td className="p-4">{route.prefix}</td>
                      <td className="p-4">{route.provider}</td>
                      <td className="p-4">{route.rate}</td>
                      <td className="p-4">{route.priority}</td>
                      <td className="p-4">{route.quality}</td>
                      <td className="p-4">
                        <Badge variant={getStatusColor(route.status)}>
                          {route.status}
                        </Badge>
                      </td>
                      <td className="p-4">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleEditRoute(route)}
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

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Least Cost Routing (LCR)</CardTitle>
            <CardDescription>Automatic route selection based on cost</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between">
              <Label>Enable LCR</Label>
              <input type="checkbox" defaultChecked className="rounded" />
            </div>
            <div className="space-y-2">
              <Label>Quality Threshold</Label>
              <Input placeholder="95%" />
            </div>
            <div className="space-y-2">
              <Label>Max Cost Difference</Label>
              <Input placeholder="10%" />
            </div>
            <Button className="w-full">Update LCR Settings</Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Failover Configuration</CardTitle>
            <CardDescription>Automatic failover for route failures</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between">
              <Label>Enable Failover</Label>
              <input type="checkbox" defaultChecked className="rounded" />
            </div>
            <div className="space-y-2">
              <Label>Failure Threshold</Label>
              <Input placeholder="3 attempts" />
            </div>
            <div className="space-y-2">
              <Label>Failover Delay</Label>
              <Input placeholder="30 seconds" />
            </div>
            <Button className="w-full">Update Failover Settings</Button>
          </CardContent>
        </Card>
      </div>

      {showForm && (
        <RouteForm
          onClose={() => setShowForm(false)}
          onRouteCreated={handleRouteCreated}
          onRouteUpdated={handleRouteUpdated}
          editingRoute={editingRoute}
        />
      )}
    </div>
  );
};

export default RouteManagement;
