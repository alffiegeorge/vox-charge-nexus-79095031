
import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Phone, Users, CreditCard, Settings, BarChart3, Building2 } from "lucide-react";
import { useToast } from "@/hooks/use-toast";

const Index = () => {
  const [loginData, setLoginData] = useState({ username: "", password: "" });
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [userType, setUserType] = useState<"admin" | "customer">("admin");
  const { toast } = useToast();

  const handleLogin = (type: "admin" | "customer") => {
    if (!loginData.username || !loginData.password) {
      toast({
        title: "Error",
        description: "Please enter username and password",
        variant: "destructive"
      });
      return;
    }
    
    setUserType(type);
    setIsLoggedIn(true);
    toast({
      title: "Login Successful",
      description: `Welcome ${type === "admin" ? "Administrator" : "Customer"}!`
    });
  };

  if (!isLoggedIn) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
        <div className="w-full max-w-md">
          <div className="text-center mb-8">
            <Phone className="h-12 w-12 text-blue-600 mx-auto mb-4" />
            <h1 className="text-3xl font-bold text-gray-900 mb-2">VoiceFlow Billing</h1>
            <p className="text-gray-600">Professional Voice Billing System</p>
          </div>
          
          <Card className="shadow-xl">
            <CardHeader>
              <CardTitle>Login to Your Account</CardTitle>
              <CardDescription>Choose your login type to continue</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="username">Username</Label>
                <Input
                  id="username"
                  placeholder="Enter your username"
                  value={loginData.username}
                  onChange={(e) => setLoginData({ ...loginData, username: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="password">Password</Label>
                <Input
                  id="password"
                  type="password"
                  placeholder="Enter your password"
                  value={loginData.password}
                  onChange={(e) => setLoginData({ ...loginData, password: e.target.value })}
                />
              </div>
              <div className="grid grid-cols-2 gap-4 pt-4">
                <Button 
                  onClick={() => handleLogin("admin")}
                  className="bg-blue-600 hover:bg-blue-700"
                >
                  <Settings className="h-4 w-4 mr-2" />
                  Admin Login
                </Button>
                <Button 
                  onClick={() => handleLogin("customer")}
                  variant="outline"
                  className="border-blue-600 text-blue-600 hover:bg-blue-50"
                >
                  <Users className="h-4 w-4 mr-2" />
                  Customer Login
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {userType === "admin" ? <AdminDashboard /> : <CustomerDashboard />}
    </div>
  );
};

const AdminDashboard = () => {
  return (
    <div className="flex h-screen bg-gray-100">
      <AdminSidebar />
      <main className="flex-1 overflow-y-auto">
        <AdminContent />
      </main>
    </div>
  );
};

const CustomerDashboard = () => {
  return (
    <div className="flex h-screen bg-gray-100">
      <CustomerSidebar />
      <main className="flex-1 overflow-y-auto">
        <CustomerContent />
      </main>
    </div>
  );
};

const AdminSidebar = () => {
  const menuItems = [
    { icon: BarChart3, label: "Dashboard", active: true },
    { icon: Users, label: "Customers" },
    { icon: Phone, label: "DID Management" },
    { icon: Building2, label: "Trunks" },
    { icon: CreditCard, label: "Billing" },
    { icon: Settings, label: "Settings" }
  ];

  return (
    <div className="w-64 bg-white shadow-lg">
      <div className="p-6 border-b">
        <div className="flex items-center space-x-2">
          <Phone className="h-8 w-8 text-blue-600" />
          <div>
            <h2 className="font-bold text-gray-900">VoiceFlow</h2>
            <p className="text-sm text-gray-500">Admin Panel</p>
          </div>
        </div>
      </div>
      <nav className="p-4">
        {menuItems.map((item, index) => (
          <button
            key={index}
            className={`w-full flex items-center space-x-3 px-4 py-3 rounded-lg mb-2 transition-colors ${
              item.active 
                ? "bg-blue-600 text-white" 
                : "text-gray-600 hover:bg-gray-100"
            }`}
          >
            <item.icon className="h-5 w-5" />
            <span>{item.label}</span>
          </button>
        ))}
      </nav>
    </div>
  );
};

const CustomerSidebar = () => {
  const menuItems = [
    { icon: BarChart3, label: "Dashboard", active: true },
    { icon: Phone, label: "Call History" },
    { icon: CreditCard, label: "Billing" },
    { icon: Settings, label: "Settings" }
  ];

  return (
    <div className="w-64 bg-white shadow-lg">
      <div className="p-6 border-b">
        <div className="flex items-center space-x-2">
          <Phone className="h-8 w-8 text-blue-600" />
          <div>
            <h2 className="font-bold text-gray-900">VoiceFlow</h2>
            <p className="text-sm text-gray-500">Customer Portal</p>
          </div>
        </div>
      </div>
      <nav className="p-4">
        {menuItems.map((item, index) => (
          <button
            key={index}
            className={`w-full flex items-center space-x-3 px-4 py-3 rounded-lg mb-2 transition-colors ${
              item.active 
                ? "bg-blue-600 text-white" 
                : "text-gray-600 hover:bg-gray-100"
            }`}
          >
            <item.icon className="h-5 w-5" />
            <span>{item.label}</span>
          </button>
        ))}
      </nav>
    </div>
  );
};

const AdminContent = () => {
  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Admin Dashboard</h1>
        <p className="text-gray-600">Manage your voice billing system</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Customers</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">1,234</div>
            <p className="text-xs text-muted-foreground">+12% from last month</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active DIDs</CardTitle>
            <Phone className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">856</div>
            <p className="text-xs text-muted-foreground">+8% from last month</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Monthly Revenue</CardTitle>
            <CreditCard className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">$45,234</div>
            <p className="text-xs text-muted-foreground">+15% from last month</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Trunks</CardTitle>
            <Building2 className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">12</div>
            <p className="text-xs text-muted-foreground">2 new this month</p>
          </CardContent>
        </Card>
      </div>

      <Tabs defaultValue="customers" className="space-y-4">
        <TabsList>
          <TabsTrigger value="customers">Customer Management</TabsTrigger>
          <TabsTrigger value="billing">Billing Management</TabsTrigger>
          <TabsTrigger value="dids">DID Management</TabsTrigger>
          <TabsTrigger value="rates">Rate Management</TabsTrigger>
        </TabsList>

        <TabsContent value="customers">
          <Card>
            <CardHeader>
              <CardTitle>Customer Management</CardTitle>
              <CardDescription>Manage customer accounts and configurations</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex justify-between items-center">
                  <Input placeholder="Search customers..." className="max-w-sm" />
                  <Button className="bg-blue-600 hover:bg-blue-700">Add New Customer</Button>
                </div>
                <div className="border rounded-lg">
                  <table className="w-full">
                    <thead className="border-b bg-gray-50">
                      <tr>
                        <th className="text-left p-4">Customer ID</th>
                        <th className="text-left p-4">Name</th>
                        <th className="text-left p-4">Type</th>
                        <th className="text-left p-4">Balance</th>
                        <th className="text-left p-4">Status</th>
                        <th className="text-left p-4">Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {[
                        { id: "C001", name: "John Doe", type: "Prepaid", balance: "$125.50", status: "Active" },
                        { id: "C002", name: "Jane Smith", type: "Postpaid", balance: "$-45.20", status: "Active" },
                        { id: "C003", name: "Bob Johnson", type: "Prepaid", balance: "$0.00", status: "Suspended" }
                      ].map((customer, index) => (
                        <tr key={index} className="border-b">
                          <td className="p-4">{customer.id}</td>
                          <td className="p-4">{customer.name}</td>
                          <td className="p-4">{customer.type}</td>
                          <td className="p-4">{customer.balance}</td>
                          <td className="p-4">
                            <span className={`px-2 py-1 rounded-full text-xs ${
                              customer.status === "Active" ? "bg-green-100 text-green-800" : "bg-red-100 text-red-800"
                            }`}>
                              {customer.status}
                            </span>
                          </td>
                          <td className="p-4">
                            <Button variant="outline" size="sm">Edit</Button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="billing">
          <Card>
            <CardHeader>
              <CardTitle>Billing Management</CardTitle>
              <CardDescription>Manage credit refills, plans, and billing configurations</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-4">
                  <h3 className="text-lg font-semibold">Credit Refill</h3>
                  <div className="space-y-2">
                    <Label>Customer ID</Label>
                    <Input placeholder="Enter customer ID" />
                  </div>
                  <div className="space-y-2">
                    <Label>Amount</Label>
                    <Input placeholder="Enter amount" type="number" />
                  </div>
                  <Button className="w-full bg-green-600 hover:bg-green-700">Process Refill</Button>
                </div>
                
                <div className="space-y-4">
                  <h3 className="text-lg font-semibold">Plan Management</h3>
                  <div className="border rounded-lg p-4">
                    <h4 className="font-medium mb-2">Available Plans</h4>
                    <div className="space-y-2">
                      {["Basic Plan - $10/month", "Standard Plan - $25/month", "Premium Plan - $50/month"].map((plan, index) => (
                        <div key={index} className="flex justify-between items-center p-2 border rounded">
                          <span>{plan}</span>
                          <Button variant="outline" size="sm">Edit</Button>
                        </div>
                      ))}
                    </div>
                    <Button className="w-full mt-4" variant="outline">Create New Plan</Button>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="dids">
          <Card>
            <CardHeader>
              <CardTitle>DID Management</CardTitle>
              <CardDescription>Manage Direct Inward Dialing numbers</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex justify-between items-center">
                  <Input placeholder="Search DIDs..." className="max-w-sm" />
                  <Button className="bg-blue-600 hover:bg-blue-700">Add New DID</Button>
                </div>
                <div className="border rounded-lg">
                  <table className="w-full">
                    <thead className="border-b bg-gray-50">
                      <tr>
                        <th className="text-left p-4">DID Number</th>
                        <th className="text-left p-4">Customer</th>
                        <th className="text-left p-4">Country</th>
                        <th className="text-left p-4">Monthly Rate</th>
                        <th className="text-left p-4">Status</th>
                        <th className="text-left p-4">Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {[
                        { number: "+1-555-0123", customer: "John Doe", country: "USA", rate: "$5.00", status: "Active" },
                        { number: "+44-20-7946-0958", customer: "Jane Smith", country: "UK", rate: "$8.00", status: "Active" },
                        { number: "+1-555-0456", customer: "Unassigned", country: "USA", rate: "$5.00", status: "Available" }
                      ].map((did, index) => (
                        <tr key={index} className="border-b">
                          <td className="p-4 font-mono">{did.number}</td>
                          <td className="p-4">{did.customer}</td>
                          <td className="p-4">{did.country}</td>
                          <td className="p-4">{did.rate}</td>
                          <td className="p-4">
                            <span className={`px-2 py-1 rounded-full text-xs ${
                              did.status === "Active" ? "bg-green-100 text-green-800" : "bg-yellow-100 text-yellow-800"
                            }`}>
                              {did.status}
                            </span>
                          </td>
                          <td className="p-4">
                            <Button variant="outline" size="sm">Manage</Button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="rates">
          <Card>
            <CardHeader>
              <CardTitle>Rate Management</CardTitle>
              <CardDescription>Configure call rates and pricing</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex justify-between items-center">
                  <Input placeholder="Search destinations..." className="max-w-sm" />
                  <Button className="bg-blue-600 hover:bg-blue-700">Add New Rate</Button>
                </div>
                <div className="border rounded-lg">
                  <table className="w-full">
                    <thead className="border-b bg-gray-50">
                      <tr>
                        <th className="text-left p-4">Destination</th>
                        <th className="text-left p-4">Prefix</th>
                        <th className="text-left p-4">Rate per Min</th>
                        <th className="text-left p-4">Connection Fee</th>
                        <th className="text-left p-4">Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {[
                        { destination: "USA Local", prefix: "1", rate: "$0.02", connection: "$0.01" },
                        { destination: "UK Mobile", prefix: "447", rate: "$0.15", connection: "$0.05" },
                        { destination: "Canada", prefix: "1", rate: "$0.03", connection: "$0.01" }
                      ].map((rate, index) => (
                        <tr key={index} className="border-b">
                          <td className="p-4">{rate.destination}</td>
                          <td className="p-4 font-mono">{rate.prefix}</td>
                          <td className="p-4">{rate.rate}</td>
                          <td className="p-4">{rate.connection}</td>
                          <td className="p-4">
                            <Button variant="outline" size="sm">Edit</Button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
};

const CustomerContent = () => {
  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Customer Dashboard</h1>
        <p className="text-gray-600">Manage your account and view usage</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <Card>
          <CardHeader>
            <CardTitle>Account Balance</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-600">$125.50</div>
            <Button className="w-full mt-4 bg-blue-600 hover:bg-blue-700">Add Credit</Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>This Month Usage</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">245 mins</div>
            <p className="text-sm text-gray-600 mt-2">$12.25 charges</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Active DIDs</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">3</div>
            <p className="text-sm text-gray-600 mt-2">Monthly cost: $15.00</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Recent Calls</CardTitle>
            <CardDescription>Your recent call activity</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {[
                { number: "+1-555-0123", duration: "5:23", cost: "$0.11", time: "2 hours ago" },
                { number: "+44-20-7946", duration: "12:45", cost: "$1.91", time: "5 hours ago" },
                { number: "+1-555-0456", duration: "3:12", cost: "$0.06", time: "1 day ago" }
              ].map((call, index) => (
                <div key={index} className="flex justify-between items-center p-3 border rounded">
                  <div>
                    <div className="font-mono">{call.number}</div>
                    <div className="text-sm text-gray-600">{call.time}</div>
                  </div>
                  <div className="text-right">
                    <div>{call.duration}</div>
                    <div className="text-sm font-semibold">{call.cost}</div>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>My DIDs</CardTitle>
            <CardDescription>Your assigned phone numbers</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {[
                { number: "+1-555-0123", type: "Local", status: "Active" },
                { number: "+1-555-0456", type: "Toll-Free", status: "Active" },
                { number: "+44-20-7946-0958", type: "International", status: "Active" }
              ].map((did, index) => (
                <div key={index} className="flex justify-between items-center p-3 border rounded">
                  <div>
                    <div className="font-mono font-semibold">{did.number}</div>
                    <div className="text-sm text-gray-600">{did.type}</div>
                  </div>
                  <span className="px-2 py-1 rounded-full text-xs bg-green-100 text-green-800">
                    {did.status}
                  </span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default Index;
