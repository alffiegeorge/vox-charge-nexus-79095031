
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";

const DUMMY_CALL_HISTORY = [
  { date: "2024-01-05", time: "14:32", number: "+1-555-0123", destination: "New York, USA", duration: "5:23", cost: "$0.11", status: "Completed" },
  { date: "2024-01-05", time: "11:15", number: "+44-20-7946", destination: "London, UK", duration: "12:45", cost: "$1.91", status: "Completed" },
  { date: "2024-01-04", time: "16:45", number: "+1-555-0456", destination: "California, USA", duration: "3:12", cost: "$0.06", status: "Completed" },
  { date: "2024-01-04", time: "09:30", number: "+49-30-123456", destination: "Berlin, Germany", duration: "8:34", cost: "$0.68", status: "Completed" },
  { date: "2024-01-03", time: "13:22", number: "+1-800-555-0789", destination: "Toll-Free", duration: "15:22", cost: "$0.00", status: "Completed" },
  { date: "2024-01-03", time: "10:15", number: "+1-555-9876", destination: "Texas, USA", duration: "2:45", cost: "$0.05", status: "Failed" },
  { date: "2024-01-02", time: "18:30", number: "+33-1-42-86", destination: "Paris, France", duration: "7:12", cost: "$0.56", status: "Completed" }
];

const CustomerCallHistory = () => {
  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Call History</h1>
        <p className="text-gray-600">View your call history and details</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Call Records</CardTitle>
          <CardDescription>Your complete call history</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <Input placeholder="Search calls..." className="max-w-sm" />
              <div className="flex space-x-2">
                <Input type="date" className="max-w-40" />
                <Button variant="outline">Filter</Button>
              </div>
            </div>
            <div className="border rounded-lg">
              <table className="w-full">
                <thead className="border-b bg-gray-50">
                  <tr>
                    <th className="text-left p-4">Date</th>
                    <th className="text-left p-4">Time</th>
                    <th className="text-left p-4">Number</th>
                    <th className="text-left p-4">Destination</th>
                    <th className="text-left p-4">Duration</th>
                    <th className="text-left p-4">Cost</th>
                    <th className="text-left p-4">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {DUMMY_CALL_HISTORY.map((call, index) => (
                    <tr key={index} className="border-b">
                      <td className="p-4">{call.date}</td>
                      <td className="p-4">{call.time}</td>
                      <td className="p-4 font-mono">{call.number}</td>
                      <td className="p-4">{call.destination}</td>
                      <td className="p-4">{call.duration}</td>
                      <td className="p-4 font-semibold">{call.cost}</td>
                      <td className="p-4">
                        <span className={`px-2 py-1 rounded-full text-xs ${
                          call.status === "Completed" ? "bg-green-100 text-green-800" : "bg-red-100 text-red-800"
                        }`}>
                          {call.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </CardContent>
      </Card>

      <div className="mt-6 grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>This Month</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">47 calls</div>
            <p className="text-sm text-gray-600">245 minutes total</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Total Cost</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">$12.25</div>
            <p className="text-sm text-gray-600">This month charges</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Success Rate</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-blue-600">95.7%</div>
            <p className="text-sm text-gray-600">Call completion rate</p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default CustomerCallHistory;
