
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { BarChart3, Download, Calendar } from "lucide-react";
import { useState } from "react";
import { useToast } from "@/hooks/use-toast";

const Reports = () => {
  const { toast } = useToast();
  
  // Revenue Report state
  const [revenueStartDate, setRevenueStartDate] = useState("");
  const [revenueEndDate, setRevenueEndDate] = useState("");
  
  // CDR state
  const [cdrCustomerId, setCdrCustomerId] = useState("");
  const [cdrStartDate, setCdrStartDate] = useState("");
  const [cdrEndDate, setCdrEndDate] = useState("");
  
  // Customer Usage state
  const [usageReportType, setUsageReportType] = useState("Monthly Usage");
  const [usageMonth, setUsageMonth] = useState("");

  const handleRevenueReport = () => {
    if (!revenueStartDate || !revenueEndDate) {
      toast({
        title: "Validation Error",
        description: "Please select both start and end dates for the revenue report.",
        variant: "destructive",
      });
      return;
    }

    if (new Date(revenueStartDate) > new Date(revenueEndDate)) {
      toast({
        title: "Date Error",
        description: "Start date cannot be later than end date.",
        variant: "destructive",
      });
      return;
    }

    console.log("Generating revenue report:", { revenueStartDate, revenueEndDate });
    
    // Simulate report generation
    setTimeout(() => {
      toast({
        title: "Revenue Report Generated",
        description: `Report for ${revenueStartDate} to ${revenueEndDate} has been generated and downloaded.`,
      });
    }, 1500);

    toast({
      title: "Generating Report",
      description: "Please wait while we generate your revenue report...",
    });
  };

  const handleCDRExport = () => {
    if (!cdrStartDate || !cdrEndDate) {
      toast({
        title: "Validation Error",
        description: "Please select both start and end dates for CDR export.",
        variant: "destructive",
      });
      return;
    }

    if (new Date(cdrStartDate) > new Date(cdrEndDate)) {
      toast({
        title: "Date Error",
        description: "Start date cannot be later than end date.",
        variant: "destructive",
      });
      return;
    }

    console.log("Exporting CDR:", { cdrCustomerId, cdrStartDate, cdrEndDate });
    
    const customerText = cdrCustomerId ? ` for customer ${cdrCustomerId}` : " for all customers";
    
    // Simulate CDR export
    setTimeout(() => {
      toast({
        title: "CDR Export Complete",
        description: `Call detail records${customerText} from ${cdrStartDate} to ${cdrEndDate} have been exported.`,
      });
    }, 2000);

    toast({
      title: "Exporting CDR",
      description: "Please wait while we export your call detail records...",
    });
  };

  const handleCustomerUsageReport = () => {
    if (!usageMonth) {
      toast({
        title: "Validation Error",
        description: "Please select a month for the customer usage report.",
        variant: "destructive",
      });
      return;
    }

    console.log("Generating customer usage report:", { usageReportType, usageMonth });
    
    // Simulate report generation
    setTimeout(() => {
      toast({
        title: "Customer Usage Report Generated",
        description: `${usageReportType} report for ${usageMonth} has been generated and downloaded.`,
      });
    }, 1500);

    toast({
      title: "Generating Report",
      description: `Please wait while we generate your ${usageReportType.toLowerCase()} report...`,
    });
  };

  const handleDownloadReport = (reportName: string) => {
    console.log("Downloading report:", reportName);
    
    toast({
      title: "Download Started",
      description: `${reportName} is being downloaded to your device.`,
    });
    
    // Simulate download
    setTimeout(() => {
      toast({
        title: "Download Complete",
        description: `${reportName} has been successfully downloaded.`,
      });
    }, 1000);
  };

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Reports & Analytics</h1>
        <p className="text-gray-600">Generate and view system reports</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <BarChart3 className="h-5 w-5 mr-2" />
              Revenue Report
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-gray-600 mb-4">Generate revenue reports by date range</p>
            <div className="space-y-2">
              <Label>Start Date</Label>
              <Input 
                type="date" 
                value={revenueStartDate}
                onChange={(e) => setRevenueStartDate(e.target.value)}
              />
              <Label>End Date</Label>
              <Input 
                type="date" 
                value={revenueEndDate}
                onChange={(e) => setRevenueEndDate(e.target.value)}
              />
            </div>
            <Button 
              className="w-full mt-4 bg-blue-600 hover:bg-blue-700"
              onClick={handleRevenueReport}
            >
              <Download className="h-4 w-4 mr-2" />
              Generate Report
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <Calendar className="h-5 w-5 mr-2" />
              Call Detail Records
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-gray-600 mb-4">Export call detail records (CDR)</p>
            <div className="space-y-2">
              <Label>Customer ID (Optional)</Label>
              <Input 
                placeholder="Leave blank for all customers" 
                value={cdrCustomerId}
                onChange={(e) => setCdrCustomerId(e.target.value)}
              />
              <Label>Start Date</Label>
              <Input 
                type="date" 
                value={cdrStartDate}
                onChange={(e) => setCdrStartDate(e.target.value)}
              />
              <Label>End Date</Label>
              <Input 
                type="date" 
                value={cdrEndDate}
                onChange={(e) => setCdrEndDate(e.target.value)}
              />
            </div>
            <Button 
              className="w-full mt-4 bg-green-600 hover:bg-green-700"
              onClick={handleCDRExport}
            >
              <Download className="h-4 w-4 mr-2" />
              Export CDR
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Customer Usage</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-gray-600 mb-4">Customer usage and billing reports</p>
            <div className="space-y-2">
              <Label>Report Type</Label>
              <select 
                className="w-full border rounded-md p-2"
                value={usageReportType}
                onChange={(e) => setUsageReportType(e.target.value)}
              >
                <option>Monthly Usage</option>
                <option>Top Customers</option>
                <option>Low Balance Alert</option>
              </select>
              <Label>Month</Label>
              <Input 
                type="month" 
                value={usageMonth}
                onChange={(e) => setUsageMonth(e.target.value)}
              />
            </div>
            <Button 
              className="w-full mt-4 bg-purple-600 hover:bg-purple-700"
              onClick={handleCustomerUsageReport}
            >
              <Download className="h-4 w-4 mr-2" />
              Generate Report
            </Button>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Quick Statistics</CardTitle>
          <CardDescription>Current month overview</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
            <div className="text-center">
              <div className="text-2xl font-bold text-blue-600">$45,234</div>
              <div className="text-sm text-gray-600">Total Revenue</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-green-600">12,450</div>
              <div className="text-sm text-gray-600">Total Calls</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-purple-600">2,340</div>
              <div className="text-sm text-gray-600">Minutes Used</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-orange-600">98.5%</div>
              <div className="text-sm text-gray-600">Success Rate</div>
            </div>
          </div>
        </CardContent>
      </Card>

      <Card className="mt-6">
        <CardHeader>
          <CardTitle>Recent Reports</CardTitle>
          <CardDescription>Previously generated reports</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            <div className="flex justify-between items-center p-3 border rounded">
              <div>
                <div className="font-medium">Monthly Revenue Report - December 2024</div>
                <div className="text-sm text-gray-600">Generated on Dec 31, 2024</div>
              </div>
              <Button 
                variant="outline" 
                size="sm"
                onClick={() => handleDownloadReport("Monthly Revenue Report - December 2024")}
              >
                <Download className="h-4 w-4 mr-2" />
                Download
              </Button>
            </div>
            <div className="flex justify-between items-center p-3 border rounded">
              <div>
                <div className="font-medium">CDR Export - Customer C001</div>
                <div className="text-sm text-gray-600">Generated on Dec 30, 2024</div>
              </div>
              <Button 
                variant="outline" 
                size="sm"
                onClick={() => handleDownloadReport("CDR Export - Customer C001")}
              >
                <Download className="h-4 w-4 mr-2" />
                Download
              </Button>
            </div>
            <div className="flex justify-between items-center p-3 border rounded">
              <div>
                <div className="font-medium">Top Customers Report</div>
                <div className="text-sm text-gray-600">Generated on Dec 29, 2024</div>
              </div>
              <Button 
                variant="outline" 
                size="sm"
                onClick={() => handleDownloadReport("Top Customers Report")}
              >
                <Download className="h-4 w-4 mr-2" />
                Download
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};

export default Reports;
