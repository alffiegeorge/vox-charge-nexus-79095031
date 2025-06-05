
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Label } from "@/components/ui/label";

const DUMMY_CUSTOMER_SMS = [
  { id: "SMS-C001-001", to: "+44-7700-900123", message: "Meeting confirmed for tomorrow", status: "Delivered", cost: "$0.08", date: "2024-01-05 14:32" },
  { id: "SMS-C001-002", to: "+1-555-0789", message: "Thanks for your business", status: "Delivered", cost: "$0.05", date: "2024-01-05 14:30" },
  { id: "SMS-C001-003", to: "+49-176-12345678", message: "Service update notification", status: "Failed", cost: "$0.00", date: "2024-01-05 14:28" },
  { id: "SMS-C001-004", to: "+33-6-12-34-56-78", message: "Welcome to our service", status: "Pending", cost: "$0.07", date: "2024-01-05 14:25" }
];

const CustomerSMS = () => {
  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">SMS Messages</h1>
        <p className="text-gray-600">Send SMS messages and view your SMS history</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle>SMS Balance</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-blue-600">1,247</div>
            <p className="text-sm text-gray-600">Credits remaining</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Sent This Month</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-600">342</div>
            <p className="text-sm text-gray-600">Messages sent</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Delivery Rate</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-purple-600">97.8%</div>
            <p className="text-sm text-gray-600">Success rate</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Total Cost</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-orange-600">$23.45</div>
            <p className="text-sm text-gray-600">This month</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle>Send SMS</CardTitle>
            <CardDescription>Send a new SMS message</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label>To</Label>
              <Input placeholder="+1-555-0123" />
            </div>
            <div className="space-y-2">
              <Label>Message</Label>
              <Textarea placeholder="Type your message here..." rows={4} />
              <div className="text-sm text-gray-500">Characters: 0/160 • Cost: $0.05</div>
            </div>
            <Button className="w-full bg-blue-600 hover:bg-blue-700">Send SMS</Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Quick Actions</CardTitle>
            <CardDescription>Common SMS actions</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <Button variant="outline" className="w-full justify-start">
              <span className="mr-2">💳</span>
              Buy SMS Credits
            </Button>
            <Button variant="outline" className="w-full justify-start">
              <span className="mr-2">📋</span>
              Manage Contacts
            </Button>
            <Button variant="outline" className="w-full justify-start">
              <span className="mr-2">📝</span>
              Message Templates
            </Button>
            <Button variant="outline" className="w-full justify-start">
              <span className="mr-2">📊</span>
              SMS Reports
            </Button>
            <Button variant="outline" className="w-full justify-start">
              <span className="mr-2">⚙️</span>
              SMS Settings
            </Button>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>SMS History</CardTitle>
          <CardDescription>Your sent messages and delivery status</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <Input placeholder="Search messages..." className="max-w-sm" />
              <Button variant="outline">Export</Button>
            </div>
            <div className="border rounded-lg">
              <table className="w-full">
                <thead className="border-b bg-gray-50">
                  <tr>
                    <th className="text-left p-4">Message ID</th>
                    <th className="text-left p-4">To</th>
                    <th className="text-left p-4">Message</th>
                    <th className="text-left p-4">Status</th>
                    <th className="text-left p-4">Cost</th>
                    <th className="text-left p-4">Date</th>
                  </tr>
                </thead>
                <tbody>
                  {DUMMY_CUSTOMER_SMS.map((sms, index) => (
                    <tr key={index} className="border-b">
                      <td className="p-4 font-mono text-sm">{sms.id}</td>
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

export default CustomerSMS;
