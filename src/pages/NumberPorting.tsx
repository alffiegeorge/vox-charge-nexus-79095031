
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Label } from "@/components/ui/label";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { useToast } from "@/hooks/use-toast";
import { useState } from "react";
import { Search, Download, Eye, Plus, Filter } from "lucide-react";

const DUMMY_PORTING = [
  { id: "PORT-001", number: "+1-555-0123", customer: "TechCorp Ltd", type: "Port-In", carrier: "Verizon", status: "In Progress", date: "2024-01-03", eta: "2024-01-10" },
  { id: "PORT-002", number: "+44-20-7946-0958", customer: "Global Comm", type: "Port-Out", carrier: "BT", status: "Completed", date: "2024-01-01", eta: "2024-01-05" },
  { id: "PORT-003", number: "+49-30-12345678", customer: "Euro Solutions", type: "Port-In", carrier: "Deutsche Telekom", status: "Pending", date: "2024-01-04", eta: "2024-01-12" },
  { id: "PORT-004", number: "+1-212-555-0789", customer: "StartUp Inc", type: "Port-In", carrier: "AT&T", status: "Rejected", date: "2024-01-02", eta: "N/A" }
];

const NumberPorting = () => {
  const { toast } = useToast();
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedPort, setSelectedPort] = useState<any>(null);
  const [formData, setFormData] = useState({
    phoneNumber: "",
    customer: "",
    portType: "Port-In",
    carrier: "",
    accountNumber: ""
  });

  const handleSubmitRequest = () => {
    if (!formData.phoneNumber || !formData.customer || !formData.carrier || !formData.accountNumber) {
      toast({
        title: "Error",
        description: "Please fill in all required fields",
        variant: "destructive"
      });
      return;
    }

    toast({
      title: "Port Request Submitted",
      description: `Port request for ${formData.phoneNumber} has been submitted successfully`
    });

    // Reset form
    setFormData({
      phoneNumber: "",
      customer: "",
      portType: "Port-In",
      carrier: "",
      accountNumber: ""
    });
  };

  const handleExportReport = () => {
    toast({
      title: "Export Started",
      description: "Your porting report is being generated and will be downloaded shortly"
    });

    // Simulate export
    setTimeout(() => {
      const data = filteredPorting.map(port => ({
        "Request ID": port.id,
        "Phone Number": port.number,
        "Customer": port.customer,
        "Type": port.type,
        "Carrier": port.carrier,
        "Status": port.status,
        "Date": port.date,
        "ETA": port.eta
      }));

      const csvContent = "data:text/csv;charset=utf-8," 
        + Object.keys(data[0]).join(",") + "\n"
        + data.map(row => Object.values(row).join(",")).join("\n");

      const encodedUri = encodeURI(csvContent);
      const link = document.createElement("a");
      link.setAttribute("href", encodedUri);
      link.setAttribute("download", `porting_report_${new Date().toISOString().split('T')[0]}.csv`);
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);

      toast({
        title: "Export Complete",
        description: "Porting report has been downloaded successfully"
      });
    }, 2000);
  };

  const handleViewPort = (port: any) => {
    setSelectedPort(port);
  };

  const filteredPorting = DUMMY_PORTING.filter(port =>
    port.id.toLowerCase().includes(searchTerm.toLowerCase()) ||
    port.number.toLowerCase().includes(searchTerm.toLowerCase()) ||
    port.customer.toLowerCase().includes(searchTerm.toLowerCase()) ||
    port.carrier.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Number Portability</h1>
        <p className="text-gray-600">Manage port-in and port-out requests with carrier coordination</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle>Total Requests</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-blue-600">24</div>
            <p className="text-sm text-gray-600">This month</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>In Progress</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-orange-600">8</div>
            <p className="text-sm text-gray-600">Active ports</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Completed</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-600">14</div>
            <p className="text-sm text-gray-600">Successfully ported</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Success Rate</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-purple-600">87.5%</div>
            <p className="text-sm text-gray-600">Overall success</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Plus className="h-5 w-5" />
              New Port Request
            </CardTitle>
            <CardDescription>Submit a new number porting request</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label>Phone Number *</Label>
              <Input 
                placeholder="+1-555-0123" 
                value={formData.phoneNumber}
                onChange={(e) => setFormData({...formData, phoneNumber: e.target.value})}
              />
            </div>
            <div className="space-y-2">
              <Label>Customer *</Label>
              <select 
                className="w-full border rounded-md p-2"
                value={formData.customer}
                onChange={(e) => setFormData({...formData, customer: e.target.value})}
              >
                <option value="">Select Customer</option>
                <option value="TechCorp Ltd">TechCorp Ltd</option>
                <option value="Global Communications">Global Communications</option>
                <option value="StartUp Inc">StartUp Inc</option>
              </select>
            </div>
            <div className="space-y-2">
              <Label>Port Type</Label>
              <select 
                className="w-full border rounded-md p-2"
                value={formData.portType}
                onChange={(e) => setFormData({...formData, portType: e.target.value})}
              >
                <option value="Port-In">Port-In</option>
                <option value="Port-Out">Port-Out</option>
              </select>
            </div>
            <div className="space-y-2">
              <Label>Current Carrier *</Label>
              <Input 
                placeholder="Verizon, AT&T, etc." 
                value={formData.carrier}
                onChange={(e) => setFormData({...formData, carrier: e.target.value})}
              />
            </div>
            <div className="space-y-2">
              <Label>Account Number *</Label>
              <Input 
                placeholder="Carrier account number" 
                value={formData.accountNumber}
                onChange={(e) => setFormData({...formData, accountNumber: e.target.value})}
              />
            </div>
            <Button className="w-full bg-blue-600 hover:bg-blue-700" onClick={handleSubmitRequest}>
              Submit Request
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Port Status Tracker</CardTitle>
            <CardDescription>Track the progress of porting requests</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-3">
              <div className="flex items-center space-x-3 p-3 border rounded">
                <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                <div className="flex-1">
                  <div className="font-medium">Request Submitted</div>
                  <div className="text-sm text-gray-600">Initial port request filed</div>
                </div>
              </div>
              <div className="flex items-center space-x-3 p-3 border rounded">
                <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                <div className="flex-1">
                  <div className="font-medium">Carrier Contacted</div>
                  <div className="text-sm text-gray-600">Reached out to losing carrier</div>
                </div>
              </div>
              <div className="flex items-center space-x-3 p-3 border rounded">
                <div className="w-3 h-3 bg-orange-500 rounded-full"></div>
                <div className="flex-1">
                  <div className="font-medium">Awaiting Approval</div>
                  <div className="text-sm text-gray-600">Waiting for carrier confirmation</div>
                </div>
              </div>
              <div className="flex items-center space-x-3 p-3 border rounded opacity-50">
                <div className="w-3 h-3 bg-gray-300 rounded-full"></div>
                <div className="flex-1">
                  <div className="font-medium">Port Scheduled</div>
                  <div className="text-sm text-gray-600">Date and time confirmed</div>
                </div>
              </div>
              <div className="flex items-center space-x-3 p-3 border rounded opacity-50">
                <div className="w-3 h-3 bg-gray-300 rounded-full"></div>
                <div className="flex-1">
                  <div className="font-medium">Port Complete</div>
                  <div className="text-sm text-gray-600">Number successfully ported</div>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Porting Requests</CardTitle>
          <CardDescription>Manage all number porting requests</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center gap-4">
              <div className="relative flex-1 max-w-sm">
                <Search className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
                <Input 
                  placeholder="Search porting requests..." 
                  className="pl-8"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>
              <Button variant="outline" onClick={handleExportReport}>
                <Download className="h-4 w-4 mr-2" />
                Export Report
              </Button>
            </div>
            <div className="border rounded-lg">
              <table className="w-full">
                <thead className="border-b bg-gray-50">
                  <tr>
                    <th className="text-left p-4">Request ID</th>
                    <th className="text-left p-4">Number</th>
                    <th className="text-left p-4">Customer</th>
                    <th className="text-left p-4">Type</th>
                    <th className="text-left p-4">Carrier</th>
                    <th className="text-left p-4">Status</th>
                    <th className="text-left p-4">Date</th>
                    <th className="text-left p-4">ETA</th>
                    <th className="text-left p-4">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredPorting.map((port, index) => (
                    <tr key={index} className="border-b">
                      <td className="p-4 font-mono">{port.id}</td>
                      <td className="p-4">{port.number}</td>
                      <td className="p-4">{port.customer}</td>
                      <td className="p-4">{port.type}</td>
                      <td className="p-4">{port.carrier}</td>
                      <td className="p-4">
                        <Badge variant={
                          port.status === "Completed" ? "default" :
                          port.status === "In Progress" ? "secondary" :
                          port.status === "Rejected" ? "destructive" :
                          "outline"
                        }>
                          {port.status}
                        </Badge>
                      </td>
                      <td className="p-4">{port.date}</td>
                      <td className="p-4">{port.eta}</td>
                      <td className="p-4">
                        <Dialog>
                          <DialogTrigger asChild>
                            <Button variant="outline" size="sm" onClick={() => handleViewPort(port)}>
                              <Eye className="h-4 w-4 mr-1" />
                              View
                            </Button>
                          </DialogTrigger>
                          <DialogContent className="max-w-2xl">
                            <DialogHeader>
                              <DialogTitle>Port Request Details - {port.id}</DialogTitle>
                              <DialogDescription>
                                Complete information about this porting request
                              </DialogDescription>
                            </DialogHeader>
                            <div className="grid grid-cols-2 gap-4 py-4">
                              <div className="space-y-4">
                                <div>
                                  <Label className="text-sm font-medium">Phone Number</Label>
                                  <p className="text-lg font-mono">{port.number}</p>
                                </div>
                                <div>
                                  <Label className="text-sm font-medium">Customer</Label>
                                  <p>{port.customer}</p>
                                </div>
                                <div>
                                  <Label className="text-sm font-medium">Port Type</Label>
                                  <p>{port.type}</p>
                                </div>
                                <div>
                                  <Label className="text-sm font-medium">Current Carrier</Label>
                                  <p>{port.carrier}</p>
                                </div>
                              </div>
                              <div className="space-y-4">
                                <div>
                                  <Label className="text-sm font-medium">Status</Label>
                                  <div className="mt-1">
                                    <Badge variant={
                                      port.status === "Completed" ? "default" :
                                      port.status === "In Progress" ? "secondary" :
                                      port.status === "Rejected" ? "destructive" :
                                      "outline"
                                    }>
                                      {port.status}
                                    </Badge>
                                  </div>
                                </div>
                                <div>
                                  <Label className="text-sm font-medium">Request Date</Label>
                                  <p>{port.date}</p>
                                </div>
                                <div>
                                  <Label className="text-sm font-medium">Estimated Completion</Label>
                                  <p>{port.eta}</p>
                                </div>
                                <div>
                                  <Label className="text-sm font-medium">Actions</Label>
                                  <div className="flex gap-2 mt-2">
                                    <Button size="sm" variant="outline">
                                      Update Status
                                    </Button>
                                    <Button size="sm" variant="outline">
                                      Contact Carrier
                                    </Button>
                                  </div>
                                </div>
                              </div>
                            </div>
                          </DialogContent>
                        </Dialog>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {filteredPorting.length === 0 && (
                <div className="text-center py-8 text-gray-500">
                  No porting requests found matching your search.
                </div>
              )}
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};

export default NumberPorting;
