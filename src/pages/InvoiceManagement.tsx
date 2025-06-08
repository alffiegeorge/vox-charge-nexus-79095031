import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Download, Send, Eye } from "lucide-react";
import { useState, useEffect } from "react";
import { useToast } from "@/hooks/use-toast";
import { apiClient } from "@/lib/api";

interface Invoice {
  id: string;
  customer: string;
  amount: string;
  date: string;
  due: string;
  status: string;
}

const InvoiceManagement = () => {
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [totalInvoiced, setTotalInvoiced] = useState("$0.00");
  const [paidInvoices, setPaidInvoices] = useState("$0.00");
  const [pendingPayment, setPendingPayment] = useState("$0.00");
  const [overdue, setOverdue] = useState("$0.00");
  const { toast } = useToast();

  useEffect(() => {
    fetchInvoices();
  }, []);

  const fetchInvoices = async () => {
    try {
      console.log('Fetching invoices from database...');
      const data = await apiClient.getAllInvoices() as any[];
      console.log('Invoices data received:', data);
      
      // Transform the data to match our interface
      const transformedInvoices = data.map((invoice: any) => ({
        id: invoice.id || invoice.invoice_id,
        customer: invoice.customer_name || invoice.customer || "Unknown Customer",
        amount: invoice.amount ? `$${invoice.amount.toFixed(2)}` : "$0.00",
        date: invoice.date || invoice.created_at,
        due: invoice.due_date || invoice.due,
        status: invoice.status
      }));
      
      setInvoices(transformedInvoices);

      // Calculate totals
      const total = data.reduce((sum: number, inv: any) => sum + (inv.amount || 0), 0);
      const paid = data.filter((inv: any) => inv.status === 'Paid').reduce((sum: number, inv: any) => sum + (inv.amount || 0), 0);
      const pending = data.filter((inv: any) => inv.status === 'Pending').reduce((sum: number, inv: any) => sum + (inv.amount || 0), 0);
      const overdueAmount = data.filter((inv: any) => inv.status === 'Overdue').reduce((sum: number, inv: any) => sum + (inv.amount || 0), 0);

      setTotalInvoiced(`$${total.toFixed(2)}`);
      setPaidInvoices(`$${paid.toFixed(2)}`);
      setPendingPayment(`$${pending.toFixed(2)}`);
      setOverdue(`$${overdueAmount.toFixed(2)}`);
      
    } catch (error) {
      console.error('Error fetching invoices:', error);
      toast({
        title: "Error",
        description: "Failed to load invoices from database",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const filteredInvoices = invoices.filter(invoice =>
    invoice.id.toLowerCase().includes(searchTerm.toLowerCase()) ||
    invoice.customer.toLowerCase().includes(searchTerm.toLowerCase()) ||
    invoice.status.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleGenerateInvoice = () => {
    toast({
      title: "Invoice Generation",
      description: "Opening invoice generation wizard...",
    });
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Invoice Management</h1>
          <p className="text-gray-600">Loading invoices from database...</p>
        </div>
        <Card>
          <CardHeader>
            <CardTitle>Loading...</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="animate-pulse space-y-4">
              {[1, 2, 3].map((i) => (
                <div key={i} className="h-16 bg-gray-200 rounded"></div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }

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
            <div className="text-3xl font-bold text-blue-600">{totalInvoiced}</div>
            <p className="text-sm text-gray-600">All time</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Paid Invoices</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-600">{paidInvoices}</div>
            <p className="text-sm text-gray-600">Total collected</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Pending Payment</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-orange-600">{pendingPayment}</div>
            <p className="text-sm text-gray-600">Awaiting payment</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Overdue</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-red-600">{overdue}</div>
            <p className="text-sm text-gray-600">Past due date</p>
          </CardContent>
        </Card>
      </div>

      <Card className="mb-6">
        <CardHeader>
          <CardTitle>Invoice List</CardTitle>
          <CardDescription>
            Manage and track all customer invoices ({invoices.length} invoices loaded from database)
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <Input 
                placeholder="Search invoices..." 
                className="max-w-sm" 
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
              <div className="flex space-x-2">
                <Button variant="outline" onClick={fetchInvoices}>
                  Refresh
                </Button>
                <Button variant="outline">Bulk Actions</Button>
                <Button className="bg-blue-600 hover:bg-blue-700" onClick={handleGenerateInvoice}>
                  Generate Invoice
                </Button>
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
                  {filteredInvoices.length > 0 ? (
                    filteredInvoices.map((invoice, index) => (
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
                    ))
                  ) : (
                    <tr>
                      <td colSpan={7} className="p-8 text-center text-gray-500">
                        {searchTerm ? `No invoices found matching "${searchTerm}"` : 'No invoices found'}
                      </td>
                    </tr>
                  )}
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
