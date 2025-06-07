import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Download, Search, Filter } from "lucide-react";
import { useState } from "react";
import { toast } from "@/hooks/use-toast";

const DUMMY_CDR = [
  { callid: "CDR-20240105-001", caller: "+1-555-0123", called: "+44-20-7946-0958", start: "2024-01-05 14:32:15", duration: "00:05:23", cost: "$0.27", status: "Completed", route: "UK-Premium" },
  { callid: "CDR-20240105-002", caller: "+1-555-0456", called: "+1-212-555-0789", start: "2024-01-05 14:30:42", duration: "00:12:45", cost: "$0.26", status: "Completed", route: "USA-Local" },
  { callid: "CDR-20240105-003", caller: "+1-555-0789", called: "+49-30-12345678", start: "2024-01-05 14:28:33", duration: "00:00:00", cost: "$0.00", status: "Failed", route: "Germany-1" },
  { callid: "CDR-20240105-004", caller: "+1-555-0321", called: "+33-1-42-86-8976", start: "2024-01-05 14:25:17", duration: "00:08:12", cost: "$0.66", status: "Completed", route: "France-Premium" }
];

const CDRManagement = () => {
  const [searchQuery, setSearchQuery] = useState("");
  const [filterDialogOpen, setFilterDialogOpen] = useState(false);
  const [advancedSearchOpen, setAdvancedSearchOpen] = useState(false);
  const [filteredRecords, setFilteredRecords] = useState(DUMMY_CDR);

  // Filter states
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [routeFilter, setRouteFilter] = useState("");

  // Advanced search states
  const [advancedCaller, setAdvancedCaller] = useState("");
  const [advancedCalled, setAdvancedCalled] = useState("");
  const [advancedCallId, setAdvancedCallId] = useState("");

  const handleSearch = (query: string) => {
    setSearchQuery(query);
    const filtered = DUMMY_CDR.filter(record => 
      record.callid.toLowerCase().includes(query.toLowerCase()) ||
      record.caller.includes(query) ||
      record.called.includes(query) ||
      record.route.toLowerCase().includes(query.toLowerCase())
    );
    setFilteredRecords(filtered);
  };

  const handleFilter = () => {
    let filtered = DUMMY_CDR;

    if (statusFilter) {
      filtered = filtered.filter(record => record.status === statusFilter);
    }
    if (routeFilter) {
      filtered = filtered.filter(record => record.route.toLowerCase().includes(routeFilter.toLowerCase()));
    }

    setFilteredRecords(filtered);
    setFilterDialogOpen(false);
    toast({
      title: "Filter Applied",
      description: `Found ${filtered.length} records matching your criteria.`,
    });
  };

  const handleAdvancedSearch = () => {
    let filtered = DUMMY_CDR;

    if (advancedCaller) {
      filtered = filtered.filter(record => record.caller.includes(advancedCaller));
    }
    if (advancedCalled) {
      filtered = filtered.filter(record => record.called.includes(advancedCalled));
    }
    if (advancedCallId) {
      filtered = filtered.filter(record => record.callid.toLowerCase().includes(advancedCallId.toLowerCase()));
    }

    setFilteredRecords(filtered);
    setAdvancedSearchOpen(false);
    toast({
      title: "Advanced Search Completed",
      description: `Found ${filtered.length} records matching your search criteria.`,
    });
  };

  const handleExport = () => {
    const csvContent = [
      ["Call ID", "Caller", "Called", "Start Time", "Duration", "Cost", "Status", "Route"],
      ...filteredRecords.map(record => [
        record.callid,
        record.caller,
        record.called,
        record.start,
        record.duration,
        record.cost,
        record.status,
        record.route
      ])
    ];

    const csvString = csvContent.map(row => row.join(",")).join("\n");
    const blob = new Blob([csvString], { type: "text/csv" });
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `cdr-export-${new Date().toISOString().split('T')[0]}.csv`;
    link.click();
    window.URL.revokeObjectURL(url);

    toast({
      title: "Export Successful",
      description: `Exported ${filteredRecords.length} call records to CSV.`,
    });
  };

  const handleViewFullAnalytics = () => {
    toast({
      title: "Full Analytics",
      description: "Opening detailed analytics dashboard...",
    });
  };

  const handleReviewAlert = (alertType: string) => {
    toast({
      title: "Alert Review",
      description: `Reviewing ${alertType} alert details...`,
    });
  };

  const clearFilters = () => {
    setSearchQuery("");
    setStatusFilter("");
    setRouteFilter("");
    setAdvancedCaller("");
    setAdvancedCalled("");
    setAdvancedCallId("");
    setFilteredRecords(DUMMY_CDR);
    toast({
      title: "Filters Cleared",
      description: "All filters have been reset.",
    });
  };

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
                <Input 
                  placeholder="Search CDR..." 
                  className="max-w-sm" 
                  value={searchQuery}
                  onChange={(e) => handleSearch(e.target.value)}
                />
                
                <Dialog open={filterDialogOpen} onOpenChange={setFilterDialogOpen}>
                  <DialogTrigger asChild>
                    <Button variant="outline">
                      <Filter className="h-4 w-4 mr-2" />
                      Filter
                    </Button>
                  </DialogTrigger>
                  <DialogContent>
                    <DialogHeader>
                      <DialogTitle>Filter Call Records</DialogTitle>
                      <DialogDescription>Apply filters to narrow down the call records</DialogDescription>
                    </DialogHeader>
                    <div className="space-y-4">
                      <div>
                        <label className="block text-sm font-medium mb-2">Status</label>
                        <select 
                          className="w-full p-2 border rounded-md"
                          value={statusFilter}
                          onChange={(e) => setStatusFilter(e.target.value)}
                        >
                          <option value="">All Statuses</option>
                          <option value="Completed">Completed</option>
                          <option value="Failed">Failed</option>
                        </select>
                      </div>
                      <div>
                        <label className="block text-sm font-medium mb-2">Route</label>
                        <Input 
                          placeholder="Enter route name"
                          value={routeFilter}
                          onChange={(e) => setRouteFilter(e.target.value)}
                        />
                      </div>
                    </div>
                    <DialogFooter>
                      <Button variant="outline" onClick={() => setFilterDialogOpen(false)}>Cancel</Button>
                      <Button onClick={handleFilter}>Apply Filter</Button>
                    </DialogFooter>
                  </DialogContent>
                </Dialog>

                <Button variant="outline" onClick={clearFilters}>
                  Clear Filters
                </Button>
              </div>
              <div className="flex space-x-2">
                <Button variant="outline" onClick={handleExport}>
                  <Download className="h-4 w-4 mr-2" />
                  Export
                </Button>

                <Dialog open={advancedSearchOpen} onOpenChange={setAdvancedSearchOpen}>
                  <DialogTrigger asChild>
                    <Button variant="outline">
                      <Search className="h-4 w-4 mr-2" />
                      Advanced Search
                    </Button>
                  </DialogTrigger>
                  <DialogContent>
                    <DialogHeader>
                      <DialogTitle>Advanced Search</DialogTitle>
                      <DialogDescription>Search call records using specific criteria</DialogDescription>
                    </DialogHeader>
                    <div className="space-y-4">
                      <div>
                        <label className="block text-sm font-medium mb-2">Caller Number</label>
                        <Input 
                          placeholder="Enter caller number"
                          value={advancedCaller}
                          onChange={(e) => setAdvancedCaller(e.target.value)}
                        />
                      </div>
                      <div>
                        <label className="block text-sm font-medium mb-2">Called Number</label>
                        <Input 
                          placeholder="Enter called number"
                          value={advancedCalled}
                          onChange={(e) => setAdvancedCalled(e.target.value)}
                        />
                      </div>
                      <div>
                        <label className="block text-sm font-medium mb-2">Call ID</label>
                        <Input 
                          placeholder="Enter call ID"
                          value={advancedCallId}
                          onChange={(e) => setAdvancedCallId(e.target.value)}
                        />
                      </div>
                    </div>
                    <DialogFooter>
                      <Button variant="outline" onClick={() => setAdvancedSearchOpen(false)}>Cancel</Button>
                      <Button onClick={handleAdvancedSearch}>Search</Button>
                    </DialogFooter>
                  </DialogContent>
                </Dialog>
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
                  {filteredRecords.map((record, index) => (
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
            {filteredRecords.length === 0 && (
              <div className="text-center py-8 text-gray-500">
                No call records found matching your criteria.
              </div>
            )}
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
              <Button size="sm" variant="outline" onClick={() => handleReviewAlert("High Volume")}>
                Review
              </Button>
            </div>
            <div className="flex justify-between items-center p-3 border rounded bg-yellow-50">
              <div>
                <div className="font-medium text-yellow-800">Unusual Pattern</div>
                <div className="text-sm text-yellow-600">Multiple short duration calls detected</div>
              </div>
              <Button size="sm" variant="outline" onClick={() => handleReviewAlert("Unusual Pattern")}>
                Review
              </Button>
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
            <Button className="w-full mt-4" onClick={handleViewFullAnalytics}>
              View Full Analytics
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default CDRManagement;
