
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Download, Eye, Search } from "lucide-react";
import { useState } from "react";
import { useToast } from "@/hooks/use-toast";

const DUMMY_CUSTOMER_INVOICES = [
  { id: "INV-2024-001", amount: "$245.50", date: "2024-01-01", due: "2024-01-31", status: "Paid", period: "December 2023" },
  { id: "INV-2024-002", amount: "$189.75", date: "2024-01-01", due: "2024-01-31", status: "Pending", period: "January 2024" },
  { id: "INV-2023-012", amount: "$267.25", date: "2023-12-01", due: "2023-12-31", status: "Paid", period: "November 2023" },
  { id: "INV-2023-011", amount: "$223.00", date: "2023-11-01", due: "2023-11-30", status: "Paid", period: "October 2023" }
];

const CustomerInvoices = () => {
  const [searchTerm, setSearchTerm] = useState("");
  const { toast } = useToast();
  
  const filteredInvoices = DUMMY_CUSTOMER_INVOICES.filter(invoice =>
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
    // In a real app, this would open a PDF viewer or navigate to invoice details
  };

  const handleDownloadInvoice = (invoiceId: string) => {
    toast({
      title: "Download Started",
      description: `Invoice ${invoiceId} is being downloaded...`,
    });
    console.log("Downloading invoice:", invoiceId);
    // In a real app, this would trigger a file download
  };

  const handleDownloadAll = () => {
    toast({
      title: "Bulk Download Started",
      description: `Preparing to download ${filteredInvoices.length} invoices...`,
    });
    console.log("Downloading all invoices:", filteredInvoices);
    // In a real app, this would create a ZIP file with all invoices
  };

  const handleSearch = () => {
    toast({
      title: "Search Applied",
      description: `Found ${filteredInvoices.length} invoices matching "${searchTerm}"`,
    });
  };

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
            <div className="text-3xl font-bold text-orange-600">$189.75</div>
            <p className="text-sm text-gray-600">Amount due</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Last Payment</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-600">$245.50</div>
            <p className="text-sm text-gray-600">Paid on Jan 15, 2024</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Next Due Date</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">Jan 31</div>
            <p className="text-sm text-gray-600">2024</p>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Invoice History</CardTitle>
          <CardDescription>View and download your invoices</CardDescription>
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
              <Button variant="outline" onClick={handleDownloadAll}>
                <Download className="h-4 w-4 mr-2" />
                Download All ({filteredInvoices.length})
              </Button>
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
                        No invoices found matching "{searchTerm}"
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
