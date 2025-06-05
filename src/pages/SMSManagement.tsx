
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";

const DUMMY_SMS = [
  { id: "SMS-001", to: "+1-555-0123", message: "Your account balance is low", status: "Delivered", cost: "$0.05", date: "2024-01-05 14:32" },
  { id: "SMS-002", to: "+44-7700-900123", message: "Payment received successfully", status: "Delivered", cost: "$0.08", date: "2024-01-05 14:30" },
  { id: "SMS-003", to: "+49-176-12345678", message: "Service maintenance scheduled", status: "Failed", cost: "$0.00", date: "2024-01-05 14:28" },
  { id: "SMS-004", to: "+33-6-12-34-56-78", message: "Welcome to our service", status: "Pending", cost: "$0.07", date: "2024-01-05 14:25" }
];

const SMSManagement = () => {
  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">SMS Management</h1>
        <p className="text-gray-600">Send SMS notifications and manage SMS campaigns</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle>SMS Sent</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-blue-600">1,234</div>
            <p className="text-sm text-gray-600">This month</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Delivered</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-600">1,189</div>
            <p className="text-sm text-gray-600">96.4% delivery rate</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Failed</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-red-600">45</div>
            <p className="text-sm text-gray-600">3.6% failure rate</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Cost</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-purple-600">$78.45</div>
            <p className="text-sm text-gray-600">This month</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle>Send SMS</CardTitle>
            <CardDescription>Send individual or bulk SMS messages</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <label className="text-sm font-medium">Recipients</label>
              <Textarea placeholder="Enter phone numbers (one per line) or select from contacts" rows={3} />
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium">Message</label>
              <Textarea placeholder="Type your message here..." rows={4} />
              <div className="text-sm text-gray-500">Characters: 0/160</div>
            </div>
            <div className="flex space-x-2">
              <Button className="flex-1 bg-blue-600 hover:bg-blue-700">Send Now</Button>
              <Button variant="outline" className="flex-1">Schedule</Button>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>SMS Templates</CardTitle>
            <CardDescription>Pre-configured message templates</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-3">
              <div className="p-3 border rounded">
                <div className="font-medium">Low Balance Alert</div>
                <div className="text-sm text-gray-600">Your account balance is low. Please top up to continue service.</div>
                <Button size="sm" className="mt-2">Use Template</Button>
              </div>
              <div className="p-3 border rounded">
                <div className="font-medium">Payment Confirmation</div>
                <div className="text-sm text-gray-600">Payment received successfully. Thank you!</div>
                <Button size="sm" className="mt-2">Use Template</Button>
              </div>
              <div className="p-3 border rounded">
                <div className="font-medium">Service Update</div>
                <div className="text-sm text-gray-600">Important service update notification.</div>
                <Button size="sm" className="mt-2">Use Template</Button>
              </div>
            </div>
            <Button variant="outline" className="w-full">Create New Template</Button>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>SMS History</CardTitle>
          <CardDescription>Track sent messages and delivery status</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <Input placeholder="Search SMS..." className="max-w-sm" />
              <Button variant="outline">Export Report</Button>
            </div>
            <div className="border rounded-lg">
              <table className="w-full">
                <thead className="border-b bg-gray-50">
                  <tr>
                    <th className="text-left p-4">SMS ID</th>
                    <th className="text-left p-4">To</th>
                    <th className="text-left p-4">Message</th>
                    <th className="text-left p-4">Status</th>
                    <th className="text-left p-4">Cost</th>
                    <th className="text-left p-4">Date</th>
                  </tr>
                </thead>
                <tbody>
                  {DUMMY_SMS.map((sms, index) => (
                    <tr key={index} className="border-b">
                      <td className="p-4 font-mono">{sms.id}</td>
                      <td className="p-4">{sms.to}</td>
                      <td className="p-4 max-w-xs truncate">{sms.message}</td>
                      <td className="p-4">
                        <Badge variant={
                          sms.status === "Delivered" ? "default" :
                          sms.status === "Failed" ? "destructive" :
                          "secondary"
                        }>
                          {sms.status}
                        </Badge>
                      </td>
                      <td className="p-4">{sms.cost}</td>
                      <td className="p-4">{sms.date}</td>
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

export default SMSManagement;
