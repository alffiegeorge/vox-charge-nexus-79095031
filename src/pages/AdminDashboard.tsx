
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Users, Phone, CreditCard, Building2 } from "lucide-react";

const DUMMY_CUSTOMERS = [
  { id: "C001", name: "John Doe", email: "john@example.com", type: "Prepaid", balance: "$125.50", status: "Active", phone: "+1-555-0123" },
  { id: "C002", name: "Jane Smith", email: "jane@example.com", type: "Postpaid", balance: "$-45.20", status: "Active", phone: "+1-555-0456" },
  { id: "C003", name: "Bob Johnson", email: "bob@example.com", type: "Prepaid", balance: "$0.00", status: "Suspended", phone: "+1-555-0789" },
  { id: "C004", name: "Alice Wilson", email: "alice@example.com", type: "Prepaid", balance: "$89.75", status: "Active", phone: "+1-555-0321" },
  { id: "C005", name: "Mike Davis", email: "mike@example.com", type: "Postpaid", balance: "$-12.80", status: "Active", phone: "+1-555-0654" }
];

const DUMMY_DIDS = [
  { number: "+1-555-0123", customer: "John Doe", country: "USA", rate: "$5.00", status: "Active", type: "Local" },
  { number: "+44-20-7946-0958", customer: "Jane Smith", country: "UK", rate: "$8.00", status: "Active", type: "International" },
  { number: "+1-555-0456", customer: "Unassigned", country: "USA", rate: "$5.00", status: "Available", type: "Local" },
  { number: "+1-800-555-0789", customer: "Bob Johnson", country: "USA", rate: "$12.00", status: "Active", type: "Toll-Free" },
  { number: "+49-30-12345678", customer: "Alice Wilson", country: "Germany", rate: "$10.00", status: "Active", type: "International" }
];

const AdminDashboard = () => {
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
            <div className="text-2xl font-bold">{DUMMY_CUSTOMERS.length}</div>
            <p className="text-xs text-muted-foreground">+12% from last month</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active DIDs</CardTitle>
            <Phone className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{DUMMY_DIDS.filter(did => did.status === "Active").length}</div>
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

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Recent Activities</CardTitle>
            <CardDescription>Latest system activities</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex justify-between items-center p-3 border rounded">
                <div>
                  <div className="font-medium">New customer registered</div>
                  <div className="text-sm text-gray-600">John Doe • 2 hours ago</div>
                </div>
              </div>
              <div className="flex justify-between items-center p-3 border rounded">
                <div>
                  <div className="font-medium">DID assigned</div>
                  <div className="text-sm text-gray-600">+1-555-0789 • 4 hours ago</div>
                </div>
              </div>
              <div className="flex justify-between items-center p-3 border rounded">
                <div>
                  <div className="font-medium">Credit refill processed</div>
                  <div className="text-sm text-gray-600">$100.00 • 1 day ago</div>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>System Status</CardTitle>
            <CardDescription>Current system health</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex justify-between items-center">
                <span>Asterisk Core</span>
                <span className="px-2 py-1 rounded-full text-xs bg-green-100 text-green-800">Online</span>
              </div>
              <div className="flex justify-between items-center">
                <span>Database</span>
                <span className="px-2 py-1 rounded-full text-xs bg-green-100 text-green-800">Healthy</span>
              </div>
              <div className="flex justify-between items-center">
                <span>SIP Trunks</span>
                <span className="px-2 py-1 rounded-full text-xs bg-green-100 text-green-800">12/12 Active</span>
              </div>
              <div className="flex justify-between items-center">
                <span>Call Quality</span>
                <span className="px-2 py-1 rounded-full text-xs bg-green-100 text-green-800">Excellent</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default AdminDashboard;
