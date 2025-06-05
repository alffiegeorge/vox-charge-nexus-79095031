
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Download, Search, Filter } from "lucide-react";

const DUMMY_CDR = [
  { callid: "CDR-20240105-001", caller: "+1-555-0123", called: "+44-20-7946-0958", start: "2024-01-05 14:32:15", duration: "00:05:23", cost: "$0.27", status: "Completed", route: "UK-Premium" },
  { callid: "CDR-20240105-002", caller: "+1-555-0456", called: "+1-212-555-0789", start: "2024-01-05 14:30:42", duration: "00:12:45", cost: "$0.26", status: "Completed", route: "USA-Local" },
  { callid: "CDR-20240105-003", caller: "+1-555-0789", called: "+49-30-12345678", start: "2024-01-05 14:28:33", duration: "00:00:00", cost: "$0.00", status: "Failed", route: "Germany-1" },
  { callid: "CDR-20240105-004", caller: "+1-555-0321", called: "+33-1-42-86-8976", start: "2024-01-05 14:25:17", duration: "00:08:12", cost: "$0.66", status: "Completed", route: "France-Premium" }
];

const CDRManagement = () => {
  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Call Detail Records</h1>
        <p className="text-gray-600">Detailed call logs, analytics, and fraud detection</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle>Total Calls</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-blue-600">24,567</div>
            <p className="text-sm text-gray-600">Last 24 hours</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Completed Calls</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-600">23,789</div>
            <p className="text-sm text-gray-600">96.8% success rate</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Failed Calls</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-red-600">778</div>
            <p className="text-sm text-gray-600">3.2% failure rate</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Revenue</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-purple-600">$1,234.56</div>
            <p className="text-sm text-gray-600">Last 24 hours</p>
          </CardContent>
        </Card>
      </div>

      <Card className="mb-6">
        <CardHeader>
          <CardTitle>Call Detail Records</CardTitle>
          <CardDescription>Search and analyze call records</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <div className="flex space-x-2">
                <Input placeholder="Search CDR..." className="max-w-sm" />
                <Button variant="outline">
                  <Filter className="h-4 w-4 mr-2" />
                  Filter
                </Button>
              </div>
              <div className="flex space-x-2">
                <Button variant="outline">
                  <Download className="h-4 w-4 mr-2" />
                  Export
                </Button>
                <Button variant="outline">
                  <Search className="h-4 w-4 mr-2" />
                  Advanced Search
                </Button>
              </div>
            </div>
            <div className="border rounded-lg">
              <table className="w-full">
                <thead className="border-b bg-gray-50">
                  <tr>
                    <th className="text-left p-4">Call ID</th>
                    <th className="text-left p-4">Caller</th>
                    <th className="text-left p-4">Called</th>
                    <th className="text-left p-4">Start Time</th>
                    <th className="text-left p-4">Duration</th>
                    <th className="text-left p-4">Cost</th>
                    <th className="text-left p-4">Status</th>
                    <th className="text-left p-4">Route</th>
                  </tr>
                </thead>
                <tbody>
                  {DUMMY_CDR.map((record, index) => (
                    <tr key={index} className="border-b hover:bg-gray-50">
                      <td className="p-4 font-mono text-sm">{record.callid}</td>
                      <td className="p-4">{record.caller}</td>
                      <td className="p-4">{record.called}</td>
                      <td className="p-4">{record.start}</td>
                      <td className="p-4">{record.duration}</td>
                      <td className="p-4 font-semibold">{record.cost}</td>
                      <td className="p-4">
                        <Badge variant={record.status === "Completed" ? "default" : "destructive"}>
                          {record.status}
                        </Badge>
                      </td>
                      <td className="p-4">{record.route}</td>
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
            <CardTitle>Fraud Detection</CardTitle>
            <CardDescription>Automated fraud monitoring alerts</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex justify-between items-center p-3 border rounded bg-red-50">
              <div>
                <div className="font-medium text-red-800">High Volume Alert</div>
                <div className="text-sm text-red-600">Customer C001: 500+ calls in 1 hour</div>
              </div>
              <Button size="sm" variant="outline">Review</Button>
            </div>
            <div className="flex justify-between items-center p-3 border rounded bg-yellow-50">
              <div>
                <div className="font-medium text-yellow-800">Unusual Pattern</div>
                <div className="text-sm text-yellow-600">Multiple short duration calls detected</div>
              </div>
              <Button size="sm" variant="outline">Review</Button>
            </div>
            <div className="flex justify-between items-center p-3 border rounded bg-green-50">
              <div>
                <div className="font-medium text-green-800">All Clear</div>
                <div className="text-sm text-green-600">No suspicious activity detected</div>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Call Analytics</CardTitle>
            <CardDescription>Real-time call statistics</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex justify-between">
              <span>Peak Hours</span>
              <span className="font-bold">2:00 PM - 4:00 PM</span>
            </div>
            <div className="flex justify-between">
              <span>Top Destination</span>
              <span className="font-bold">United Kingdom</span>
            </div>
            <div className="flex justify-between">
              <span>Avg Call Duration</span>
              <span className="font-bold">4:23 minutes</span>
            </div>
            <div className="flex justify-between">
              <span>Most Active Customer</span>
              <span className="font-bold">TechCorp Ltd</span>
            </div>
            <Button className="w-full mt-4">View Full Analytics</Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default CDRManagement;
