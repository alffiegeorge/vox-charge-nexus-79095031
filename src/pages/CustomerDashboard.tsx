
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";

const DUMMY_RECENT_CALLS = [
  { number: "+1-555-0123", duration: "5:23", cost: "$0.11", time: "2 hours ago", destination: "New York" },
  { number: "+44-20-7946", duration: "12:45", cost: "$1.91", time: "5 hours ago", destination: "London" },
  { number: "+1-555-0456", duration: "3:12", cost: "$0.06", time: "1 day ago", destination: "California" },
  { number: "+49-30-123456", duration: "8:34", cost: "$0.68", time: "2 days ago", destination: "Berlin" },
  { number: "+1-800-555-0789", duration: "15:22", cost: "$0.00", time: "3 days ago", destination: "Toll-Free" }
];

const DUMMY_DIDS = [
  { number: "+1-555-0123", customer: "John Doe", country: "USA", rate: "$5.00", status: "Active", type: "Local" },
  { number: "+44-20-7946-0958", customer: "Jane Smith", country: "UK", rate: "$8.00", status: "Active", type: "International" },
  { number: "+49-30-12345678", customer: "Alice Wilson", country: "Germany", rate: "$10.00", status: "Active", type: "International" }
];

const CustomerDashboard = () => {
  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Customer Dashboard</h1>
        <p className="text-gray-600">Welcome back, John Doe!</p>
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
              {DUMMY_RECENT_CALLS.map((call, index) => (
                <div key={index} className="flex justify-between items-center p-3 border rounded">
                  <div>
                    <div className="font-mono">{call.number}</div>
                    <div className="text-sm text-gray-600">{call.destination} • {call.time}</div>
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
              {DUMMY_DIDS.filter(did => did.customer !== "Unassigned").slice(0, 3).map((did, index) => (
                <div key={index} className="flex justify-between items-center p-3 border rounded">
                  <div>
                    <div className="font-mono font-semibold">{did.number}</div>
                    <div className="text-sm text-gray-600">{did.type} • {did.country}</div>
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

export default CustomerDashboard;
