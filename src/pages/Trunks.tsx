
import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useToast } from "@/hooks/use-toast";
import TrunkForm from "@/components/TrunkForm";

interface Trunk {
  name: string;
  provider: string;
  sipServer: string;
  maxChannels: number;
  status: string;
  quality: string;
  channels: string;
  username?: string;
  password?: string;
  port?: string;
  notes?: string;
}

const INITIAL_TRUNKS: Trunk[] = [
  { name: "Primary SIP Trunk", provider: "VoIP Provider A", sipServer: "sip1.provider.com", maxChannels: 30, status: "Active", channels: "30/30", quality: "Excellent" },
  { name: "Backup SIP Trunk", provider: "VoIP Provider B", sipServer: "sip2.provider.com", maxChannels: 20, status: "Active", channels: "20/20", quality: "Good" },
  { name: "International Trunk", provider: "Global VoIP Inc", sipServer: "international.voip.com", maxChannels: 15, status: "Active", channels: "15/15", quality: "Excellent" },
  { name: "Emergency Trunk", provider: "Backup Solutions", sipServer: "emergency.backup.com", maxChannels: 10, status: "Standby", channels: "10/10", quality: "Good" }
];

const Trunks = () => {
  const [trunks, setTrunks] = useState<Trunk[]>(INITIAL_TRUNKS);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [editingTrunk, setEditingTrunk] = useState<Trunk | null>(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [testingTrunk, setTestingTrunk] = useState<string | null>(null);
  const { toast } = useToast();

  const handleTrunkCreated = (newTrunk: Trunk) => {
    const trunkWithChannels = {
      ...newTrunk,
      channels: `${newTrunk.maxChannels}/${newTrunk.maxChannels}`
    };
    setTrunks(prev => [...prev, trunkWithChannels]);
  };

  const handleTrunkUpdated = (updatedTrunk: Trunk) => {
    setTrunks(prev => prev.map(trunk => 
      trunk.name === editingTrunk?.name ? {
        ...updatedTrunk,
        channels: `${updatedTrunk.maxChannels}/${updatedTrunk.maxChannels}`
      } : trunk
    ));
    setEditingTrunk(null);
  };

  const handleEditTrunk = (trunk: Trunk) => {
    setEditingTrunk(trunk);
  };

  const handleTestTrunk = async (trunk: Trunk) => {
    setTestingTrunk(trunk.name);
    
    // Simulate trunk testing
    setTimeout(() => {
      const isSuccessful = Math.random() > 0.2; // 80% success rate
      
      if (isSuccessful) {
        toast({
          title: "Trunk Test Successful",
          description: `Connection to ${trunk.name} is working properly`,
        });
      } else {
        toast({
          title: "Trunk Test Failed",
          description: `Failed to connect to ${trunk.name}. Please check configuration.`,
          variant: "destructive"
        });
      }
      
      setTestingTrunk(null);
    }, 2000);
  };

  const handleCloseForm = () => {
    setShowCreateForm(false);
    setEditingTrunk(null);
  };

  const filteredTrunks = trunks.filter(trunk =>
    trunk.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    trunk.provider.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Trunk Management</h1>
        <p className="text-gray-600">Manage SIP trunks and connections</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle>Quick Add Trunk</CardTitle>
            <CardDescription>Basic trunk configuration for quick setup</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label>Trunk Name</Label>
              <Input placeholder="Enter trunk name" />
            </div>
            <div className="space-y-2">
              <Label>Provider</Label>
              <Input placeholder="Provider name" />
            </div>
            <div className="space-y-2">
              <Label>SIP Server</Label>
              <Input placeholder="sip.provider.com" />
            </div>
            <div className="space-y-2">
              <Label>Max Channels</Label>
              <Input placeholder="30" type="number" />
            </div>
            <Button 
              className="w-full bg-blue-600 hover:bg-blue-700"
              onClick={() => setShowCreateForm(true)}
            >
              Add Trunk (Advanced)
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Trunk Statistics</CardTitle>
            <CardDescription>Current trunk usage and performance</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex justify-between items-center">
                <span>Total Trunks</span>
                <span className="font-semibold">{trunks.length}</span>
              </div>
              <div className="flex justify-between items-center">
                <span>Active Trunks</span>
                <span className="font-semibold">{trunks.filter(t => t.status === "Active").length}</span>
              </div>
              <div className="flex justify-between items-center">
                <span>Total Channels</span>
                <span className="font-semibold">{trunks.reduce((sum, trunk) => sum + trunk.maxChannels, 0)}</span>
              </div>
              <div className="flex justify-between items-center">
                <span>Used Channels</span>
                <span className="font-semibold">23</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Trunk List</CardTitle>
          <CardDescription>Manage existing SIP trunks</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <Input 
                placeholder="Search trunks..." 
                className="max-w-sm" 
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
              <div className="flex space-x-2">
                <Button variant="outline">Refresh Status</Button>
                <Button 
                  className="bg-blue-600 hover:bg-blue-700"
                  onClick={() => setShowCreateForm(true)}
                >
                  Add New Trunk
                </Button>
              </div>
            </div>
            <div className="border rounded-lg">
              <table className="w-full">
                <thead className="border-b bg-gray-50">
                  <tr>
                    <th className="text-left p-4">Trunk Name</th>
                    <th className="text-left p-4">Provider</th>
                    <th className="text-left p-4">SIP Server</th>
                    <th className="text-left p-4">Status</th>
                    <th className="text-left p-4">Channels</th>
                    <th className="text-left p-4">Quality</th>
                    <th className="text-left p-4">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredTrunks.map((trunk, index) => (
                    <tr key={index} className="border-b">
                      <td className="p-4 font-medium">{trunk.name}</td>
                      <td className="p-4">{trunk.provider}</td>
                      <td className="p-4 font-mono text-sm">{trunk.sipServer}</td>
                      <td className="p-4">
                        <span className={`px-2 py-1 rounded-full text-xs ${
                          trunk.status === "Active" ? "bg-green-100 text-green-800" : 
                          trunk.status === "Standby" ? "bg-yellow-100 text-yellow-800" :
                          "bg-red-100 text-red-800"
                        }`}>
                          {trunk.status}
                        </span>
                      </td>
                      <td className="p-4">{trunk.channels}</td>
                      <td className="p-4">
                        <span className={`px-2 py-1 rounded-full text-xs ${
                          trunk.quality === "Excellent" ? "bg-green-100 text-green-800" : 
                          trunk.quality === "Good" ? "bg-blue-100 text-blue-800" :
                          trunk.quality === "Fair" ? "bg-yellow-100 text-yellow-800" :
                          "bg-red-100 text-red-800"
                        }`}>
                          {trunk.quality}
                        </span>
                      </td>
                      <td className="p-4">
                        <div className="flex space-x-2">
                          <Button 
                            variant="outline" 
                            size="sm"
                            onClick={() => handleEditTrunk(trunk)}
                          >
                            Edit
                          </Button>
                          <Button 
                            variant="outline" 
                            size="sm"
                            onClick={() => handleTestTrunk(trunk)}
                            disabled={testingTrunk === trunk.name}
                          >
                            {testingTrunk === trunk.name ? "Testing..." : "Test"}
                          </Button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </CardContent>
      </Card>

      {(showCreateForm || editingTrunk) && (
        <TrunkForm
          onClose={handleCloseForm}
          onTrunkCreated={handleTrunkCreated}
          onTrunkUpdated={handleTrunkUpdated}
          editingTrunk={editingTrunk}
        />
      )}
    </div>
  );
};

export default Trunks;
