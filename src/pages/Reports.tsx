
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { BarChart3, Download, Calendar } from "lucide-react";

const Reports = () => {
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
              <Label>Date Range</Label>
              <Input type="date" />
              <Input type="date" />
            </div>
            <Button className="w-full mt-4 bg-blue-600 hover:bg-blue-700">
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
              <Input placeholder="Leave blank for all customers" />
              <Label>Date Range</Label>
              <Input type="date" />
              <Input type="date" />
            </div>
            <Button className="w-full mt-4 bg-green-600 hover:bg-green-700">
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
              <select className="w-full border rounded-md p-2">
                <option>Monthly Usage</option>
                <option>Top Customers</option>
                <option>Low Balance Alert</option>
              </select>
              <Label>Month</Label>
              <Input type="month" />
            </div>
            <Button className="w-full mt-4 bg-purple-600 hover:bg-purple-700">
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
              <Button variant="outline" size="sm">
                <Download className="h-4 w-4 mr-2" />
                Download
              </Button>
            </div>
            <div className="flex justify-between items-center p-3 border rounded">
              <div>
                <div className="font-medium">CDR Export - Customer C001</div>
                <div className="text-sm text-gray-600">Generated on Dec 30, 2024</div>
              </div>
              <Button variant="outline" size="sm">
                <Download className="h-4 w-4 mr-2" />
                Download
              </Button>
            </div>
            <div className="flex justify-between items-center p-3 border rounded">
              <div>
                <div className="font-medium">Top Customers Report</div>
                <div className="text-sm text-gray-600">Generated on Dec 29, 2024</div>
              </div>
              <Button variant="outline" size="sm">
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
