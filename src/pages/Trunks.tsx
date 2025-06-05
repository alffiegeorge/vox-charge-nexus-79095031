
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

const DUMMY_TRUNKS = [
  { name: "Primary SIP Trunk", provider: "VoIP Provider A", status: "Active", channels: "30/30", quality: "Excellent" },
  { name: "Backup SIP Trunk", provider: "VoIP Provider B", status: "Active", channels: "20/20", quality: "Good" },
  { name: "International Trunk", provider: "Global VoIP Inc", status: "Active", channels: "15/15", quality: "Excellent" },
  { name: "Emergency Trunk", provider: "Backup Solutions", status: "Standby", channels: "10/10", quality: "Good" }
];

const Trunks = () => {
  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Trunk Management</h1>
        <p className="text-gray-600">Manage SIP trunks and connections</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle>Add New Trunk</CardTitle>
            <CardDescription>Configure a new SIP trunk connection</CardDescription>
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
            <Button className="w-full bg-blue-600 hover:bg-blue-700">Add Trunk</Button>
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
                <span className="font-semibold">{DUMMY_TRUNKS.length}</span>
              </div>
              <div className="flex justify-between items-center">
                <span>Active Trunks</span>
                <span className="font-semibold">{DUMMY_TRUNKS.filter(t => t.status === "Active").length}</span>
              </div>
              <div className="flex justify-between items-center">
                <span>Total Channels</span>
                <span className="font-semibold">75</span>
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
              <Input placeholder="Search trunks..." className="max-w-sm" />
              <Button variant="outline">Refresh Status</Button>
            </div>
            <div className="border rounded-lg">
              <table className="w-full">
                <thead className="border-b bg-gray-50">
                  <tr>
                    <th className="text-left p-4">Trunk Name</th>
                    <th className="text-left p-4">Provider</th>
                    <th className="text-left p-4">Status</th>
                    <th className="text-left p-4">Channels</th>
                    <th className="text-left p-4">Quality</th>
                    <th className="text-left p-4">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {DUMMY_TRUNKS.map((trunk, index) => (
                    <tr key={index} className="border-b">
                      <td className="p-4 font-medium">{trunk.name}</td>
                      <td className="p-4">{trunk.provider}</td>
                      <td className="p-4">
                        <span className={`px-2 py-1 rounded-full text-xs ${
                          trunk.status === "Active" ? "bg-green-100 text-green-800" : "bg-yellow-100 text-yellow-800"
                        }`}>
                          {trunk.status}
                        </span>
                      </td>
                      <td className="p-4">{trunk.channels}</td>
                      <td className="p-4">
                        <span className={`px-2 py-1 rounded-full text-xs ${
                          trunk.quality === "Excellent" ? "bg-green-100 text-green-800" : "bg-blue-100 text-blue-800"
                        }`}>
                          {trunk.quality}
                        </span>
                      </td>
                      <td className="p-4">
                        <div className="flex space-x-2">
                          <Button variant="outline" size="sm">Edit</Button>
                          <Button variant="outline" size="sm">Test</Button>
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
    </div>
  );
};

export default Trunks;
