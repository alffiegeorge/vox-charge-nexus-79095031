
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Download, Eye, Search } from "lucide-react";
import { useState, useEffect } from "react";
import { useToast } from "@/hooks/use-toast";
import { apiClient } from "@/lib/api";

interface Invoice {
  id: string;
  amount: string;
  date: string;
  due: string;
  status: string;
  period: string;
}

const CustomerInvoices = () => {
  const [searchTerm, setSearchTerm] = useState("");
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [loading, setLoading] = useState(true);
  const [currentBalance, setCurrentBalance] = useState("$0.00");
  const [lastPayment, setLastPayment] = useState("$0.00");
  const [nextDueDate, setNextDueDate] = useState("N/A");
  const { toast } = useToast();

  useEffect(() => {
    fetchInvoices();
  }, []);

  const fetchInvoices = async () => {
    try {
      console.log('Fetching invoices from database...');
      const data = await apiClient.getCustomerInvoices() as any[];
      console.log('Invoices data received:', data);
      
      // Transform the data to match our interface
      const transformedInvoices = data.map((invoice: any) => ({
        id: invoice.id || invoice.invoice_id,
        amount: invoice.amount ? `$${invoice.amount.toFixed(2)}` : "$0.00",
        date: invoice.date || invoice.created_at,
        due: invoice.due_date || invoice.due,
        status: invoice.status,
        period: invoice.period || invoice.billing_period
      }));
      
      setInvoices(transformedInvoices);

      // Set summary data from API if available
      if (data.length > 0) {
        const pendingInvoices = data.filter((inv: any) => inv.status === 'Pending');
        const paidInvoices = data.filter((inv: any) => inv.status === 'Paid');
        
        if (pendingInvoices.length > 0) {
          setCurrentBalance(`$${pendingInvoices[0].amount?.toFixed(2) || '0.00'}`);
        }
        
        if (paidInvoices.length > 0) {
          setLastPayment(`$${paidInvoices[paidInvoices.length - 1].amount?.toFixed(2) || '0.00'}`);
        }
      }
      
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
    invoice.period.toLowerCase().includes(searchTerm.toLowerCase()) ||
    invoice.status.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleViewInvoice = (invoiceId: string) => {
    toast({
      title: "Invoice Viewer",
      description: `Opening invoice ${invoiceId} in a new window...`,
    });
    console.log("Viewing invoice:", invoiceId);
  };

  const handleDownloadInvoice = (invoiceId: string) => {
    toast({
      title: "Download Started",
      description: `Invoice ${invoiceId} is being downloaded...`,
    });
    console.log("Downloading invoice:", invoiceId);
  };

  const handleDownloadAll = () => {
    toast({
      title: "Bulk Download Started",
      description: `Preparing to download ${filteredInvoices.length} invoices...`,
    });
    console.log("Downloading all invoices:", filteredInvoices);
  };

  const handleSearch = () => {
    toast({
      title: "Search Applied",
      description: `Found ${filteredInvoices.length} invoices matching "${searchTerm}"`,
    });
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">My Invoices</h1>
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
        <h1 className="text-3xl font-bold text-gray-900 mb-2">My Invoices</h1>
        <p className="text-gray-600">View and download your invoices</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle>Current Balance</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-orange-600">{currentBalance}</div>
            <p className="text-sm text-gray-600">Amount due</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Last Payment</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-600">{lastPayment}</div>
            <p className="text-sm text-gray-600">Most recent payment</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Next Due Date</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{nextDueDate}</div>
            <p className="text-sm text-gray-600">Upcoming payment</p>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Invoice History</CardTitle>
          <CardDescription>
            View and download your invoices ({invoices.length} invoices loaded from database)
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center gap-4">
              <div className="flex items-center space-x-2 max-w-sm flex-1">
                <Input 
                  placeholder="Search invoices..." 
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
                />
                <Button variant="outline" size="sm" onClick={handleSearch}>
                  <Search className="h-4 w-4" />
                </Button>
              </div>
              <div className="flex space-x-2">
                <Button variant="outline" onClick={fetchInvoices}>
                  Refresh
                </Button>
                <Button variant="outline" onClick={handleDownloadAll}>
                  <Download className="h-4 w-4 mr-2" />
                  Download All ({filteredInvoices.length})
                </Button>
              </div>
            </div>
            <div className="border rounded-lg">
              <table className="w-full">
                <thead className="border-b bg-gray-50">
                  <tr>
                    <th className="text-left p-4">Invoice</th>
                    <th className="text-left p-4">Period</th>
                    <th className="text-left p-4">Amount</th>
                    <th className="text-left p-4">Due Date</th>
                    <th className="text-left p-4">Status</th>
                    <th className="text-left p-4">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredInvoices.length > 0 ? (
                    filteredInvoices.map((invoice, index) => (
                      <tr key={index} className="border-b hover:bg-gray-50">
                        <td className="p-4 font-mono">{invoice.id}</td>
                        <td className="p-4">{invoice.period}</td>
                        <td className="p-4 font-semibold">{invoice.amount}</td>
                        <td className="p-4">{invoice.due}</td>
                        <td className="p-4">
                          <Badge variant={
                            invoice.status === "Paid" ? "default" : "secondary"
                          }>
                            {invoice.status}
                          </Badge>
                        </td>
                        <td className="p-4">
                          <div className="flex space-x-2">
                            <Button 
                              variant="outline" 
                              size="sm"
                              onClick={() => handleViewInvoice(invoice.id)}
                              title="View Invoice"
                            >
                              <Eye className="h-4 w-4" />
                            </Button>
                            <Button 
                              variant="outline" 
                              size="sm"
                              onClick={() => handleDownloadInvoice(invoice.id)}
                              title="Download Invoice"
                            >
                              <Download className="h-4 w-4" />
                            </Button>
                          </div>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={6} className="p-8 text-center text-gray-500">
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
    </div>
  );
};

export default CustomerInvoices;
