
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Download, Send, Eye } from "lucide-react";

const DUMMY_INVOICES = [
  { id: "INV-2024-001", customer: "TechCorp Ltd", amount: "$1,245.50", date: "2024-01-01", due: "2024-01-31", status: "Paid" },
  { id: "INV-2024-002", customer: "Global Communications", amount: "$2,890.75", date: "2024-01-01", due: "2024-01-31", status: "Pending" },
  { id: "INV-2024-003", customer: "StartUp Inc", amount: "$567.25", date: "2024-01-01", due: "2024-01-31", status: "Overdue" },
  { id: "INV-2024-004", customer: "Enterprise Solutions", amount: "$4,123.00", date: "2024-01-01", due: "2024-01-31", status: "Draft" }
];

const InvoiceManagement = () => {
  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Invoice Management</h1>
        <p className="text-gray-600">Generate, send, and manage customer invoices</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle>Total Invoiced</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-blue-600">$8,826.50</div>
            <p className="text-sm text-gray-600">This month</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Paid Invoices</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-600">$1,245.50</div>
            <p className="text-sm text-gray-600">14% of total</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Pending Payment</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-orange-600">$2,890.75</div>
            <p className="text-sm text-gray-600">33% of total</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Overdue</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-red-600">$567.25</div>
            <p className="text-sm text-gray-600">6% of total</p>
          </CardContent>
        </Card>
      </div>

      <Card className="mb-6">
        <CardHeader>
          <CardTitle>Invoice List</CardTitle>
          <CardDescription>Manage and track all customer invoices</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <Input placeholder="Search invoices..." className="max-w-sm" />
              <div className="flex space-x-2">
                <Button variant="outline">Bulk Actions</Button>
                <Button className="bg-blue-600 hover:bg-blue-700">Generate Invoice</Button>
              </div>
            </div>
            <div className="border rounded-lg">
              <table className="w-full">
                <thead className="border-b bg-gray-50">
                  <tr>
                    <th className="text-left p-4">Invoice ID</th>
                    <th className="text-left p-4">Customer</th>
                    <th className="text-left p-4">Amount</th>
                    <th className="text-left p-4">Date</th>
                    <th className="text-left p-4">Due Date</th>
                    <th className="text-left p-4">Status</th>
                    <th className="text-left p-4">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {DUMMY_INVOICES.map((invoice, index) => (
                    <tr key={index} className="border-b">
                      <td className="p-4 font-mono">{invoice.id}</td>
                      <td className="p-4">{invoice.customer}</td>
                      <td className="p-4 font-semibold">{invoice.amount}</td>
                      <td className="p-4">{invoice.date}</td>
                      <td className="p-4">{invoice.due}</td>
                      <td className="p-4">
                        <Badge variant={
                          invoice.status === "Paid" ? "default" :
                          invoice.status === "Pending" ? "secondary" :
                          invoice.status === "Overdue" ? "destructive" :
                          "outline"
                        }>
                          {invoice.status}
                        </Badge>
                      </td>
                      <td className="p-4">
                        <div className="flex space-x-2">
                          <Button variant="outline" size="sm">
                            <Eye className="h-4 w-4" />
                          </Button>
                          <Button variant="outline" size="sm">
                            <Download className="h-4 w-4" />
                          </Button>
                          <Button variant="outline" size="sm">
                            <Send className="h-4 w-4" />
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

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Auto-Invoice Settings</CardTitle>
            <CardDescription>Configure automatic invoice generation</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between">
              <span>Enable Auto-Generation</span>
              <input type="checkbox" defaultChecked className="rounded" />
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium">Generation Day</label>
              <select className="w-full border rounded-md p-2">
                <option>1st of month</option>
                <option>15th of month</option>
                <option>Last day of month</option>
              </select>
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium">Payment Terms</label>
              <select className="w-full border rounded-md p-2">
                <option>Net 30</option>
                <option>Net 15</option>
                <option>Due on Receipt</option>
              </select>
            </div>
            <Button className="w-full">Save Settings</Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Payment Reminders</CardTitle>
            <CardDescription>Automated payment reminder settings</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between">
              <span>Send Reminders</span>
              <input type="checkbox" defaultChecked className="rounded" />
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium">First Reminder</label>
              <Input placeholder="7 days before due date" />
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium">Final Notice</label>
              <Input placeholder="3 days after due date" />
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium">Overdue Action</label>
              <select className="w-full border rounded-md p-2">
                <option>Send notice only</option>
                <option>Suspend service</option>
                <option>Apply late fee</option>
              </select>
            </div>
            <Button className="w-full">Update Reminders</Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default InvoiceManagement;
