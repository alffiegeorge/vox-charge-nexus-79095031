import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle, AlertDialogTrigger } from "@/components/ui/alert-dialog";
import { useToast } from "@/hooks/use-toast";

const DUMMY_LOGS = [
  { id: "LOG-001", user: "admin", action: "Customer Created", resource: "Customer C005", ip: "192.168.1.100", timestamp: "2024-01-05 14:32:15", status: "Success" },
  { id: "LOG-002", user: "sarah.johnson", action: "Rate Updated", resource: "Rate R123", ip: "192.168.1.105", timestamp: "2024-01-05 14:30:42", status: "Success" },
  { id: "LOG-003", user: "mike.wilson", action: "Login Failed", resource: "Admin Panel", ip: "192.168.1.110", timestamp: "2024-01-05 14:28:33", status: "Failed" },
  { id: "LOG-004", user: "admin", action: "DID Assigned", resource: "DID +1-555-0123", ip: "192.168.1.100", timestamp: "2024-01-05 14:25:17", status: "Success" },
  { id: "LOG-005", user: "lisa.davis", action: "Invoice Generated", resource: "Invoice INV-2024-005", ip: "192.168.1.115", timestamp: "2024-01-05 14:22:08", status: "Success" }
];

const AuditLogs = () => {
  const { toast } = useToast();
  const [searchTerm, setSearchTerm] = useState("");
  const [actionFilter, setActionFilter] = useState("All Actions");
  const [filteredLogs, setFilteredLogs] = useState(DUMMY_LOGS);
  const [isRetentionDialogOpen, setIsRetentionDialogOpen] = useState(false);
  const [retentionSettings, setRetentionSettings] = useState({
    period: "90",
    autoArchive: true,
    compression: true
  });

  const handleSearch = () => {
    console.log("Searching logs with term:", searchTerm);
    let filtered = DUMMY_LOGS;
    
    if (searchTerm) {
      filtered = filtered.filter(log => 
        log.user.toLowerCase().includes(searchTerm.toLowerCase()) ||
        log.action.toLowerCase().includes(searchTerm.toLowerCase()) ||
        log.resource.toLowerCase().includes(searchTerm.toLowerCase()) ||
        log.id.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    if (actionFilter !== "All Actions") {
      const filterMap = {
        "Login/Logout": ["Login Failed", "Logout"],
        "Data Changes": ["Customer Created", "Rate Updated", "DID Assigned"],
        "System Config": ["System Config"],
        "Failed Actions": filtered.filter(log => log.status === "Failed")
      };
      
      if (actionFilter === "Failed Actions") {
        filtered = filtered.filter(log => log.status === "Failed");
      } else if (filterMap[actionFilter]) {
        filtered = filtered.filter(log => filterMap[actionFilter].includes(log.action));
      }
    }

    setFilteredLogs(filtered);
    toast({
      title: "Search Applied",
      description: `Found ${filtered.length} matching logs`,
    });
  };

  const handleFilterByDate = () => {
    console.log("Opening date filter dialog");
    toast({
      title: "Date Filter",
      description: "Date range picker would open here",
    });
  };

  const handleExportLogs = () => {
    console.log("Exporting logs:", filteredLogs);
    toast({
      title: "Export Started",
      description: "Audit logs are being exported to CSV format",
    });
    
    // Simulate export
    setTimeout(() => {
      toast({
        title: "Export Complete",
        description: "Audit logs have been downloaded successfully",
      });
    }, 2000);
  };

  const handleBlockIP = (ip: string) => {
    console.log("Blocking IP:", ip);
    toast({
      title: "IP Blocked",
      description: `IP address ${ip} has been added to the blocklist`,
    });
  };

  const handleReviewAlert = (alertType: string) => {
    console.log("Reviewing alert:", alertType);
    toast({
      title: "Alert Under Review",
      description: `${alertType} alert has been marked for review`,
    });
  };

  const handleGenerateReport = (reportType: string) => {
    console.log("Generating report:", reportType);
    toast({
      title: "Report Generation Started",
      description: `${reportType} is being generated`,
    });
    
    // Simulate report generation
    setTimeout(() => {
      toast({
        title: "Report Ready",
        description: `${reportType} has been generated and is ready for download`,
      });
    }, 3000);
  };

  const handleRetentionSave = () => {
    console.log("Saving retention settings:", retentionSettings);
    toast({
      title: "Settings Saved",
      description: "Data retention policies have been updated successfully",
    });
    setIsRetentionDialogOpen(false);
  };

  // Apply search when search term or filter changes
  const applyFilters = () => {
    handleSearch();
  };

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Audit Logs</h1>
        <p className="text-gray-600">System activity tracking and compliance reporting</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle>Total Actions</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-blue-600">1,247</div>
            <p className="text-sm text-gray-600">Last 24 hours</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Successful</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-600">1,198</div>
            <p className="text-sm text-gray-600">96.1% success rate</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Failed Actions</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-red-600">49</div>
            <p className="text-sm text-gray-600">3.9% failure rate</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Unique Users</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-purple-600">23</div>
            <p className="text-sm text-gray-600">Active users</p>
          </CardContent>
        </Card>
      </div>

      <Card className="mb-6">
        <CardHeader>
          <CardTitle>Security Alerts</CardTitle>
          <CardDescription>Recent security events and anomalies</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            <div className="flex items-center justify-between p-3 border rounded bg-red-50">
              <div>
                <div className="font-medium text-red-800">Multiple Failed Logins</div>
                <div className="text-sm text-red-600">IP: 203.0.113.42 - 5 failed attempts in 10 minutes</div>
                <div className="text-xs text-red-500">2024-01-05 14:25:00</div>
              </div>
              <Button 
                size="sm" 
                variant="outline"
                onClick={() => handleBlockIP("203.0.113.42")}
              >
                Block IP
              </Button>
            </div>
            <div className="flex items-center justify-between p-3 border rounded bg-yellow-50">
              <div>
                <div className="font-medium text-yellow-800">Unusual Admin Activity</div>
                <div className="text-sm text-yellow-600">Bulk customer deletion by admin user</div>
                <div className="text-xs text-yellow-500">2024-01-05 13:45:00</div>
              </div>
              <Button 
                size="sm" 
                variant="outline"
                onClick={() => handleReviewAlert("Unusual Admin Activity")}
              >
                Review
              </Button>
            </div>
            <div className="flex items-center justify-between p-3 border rounded bg-green-50">
              <div>
                <div className="font-medium text-green-800">System Status Normal</div>
                <div className="text-sm text-green-600">No security alerts in the last hour</div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>System Activity Logs</CardTitle>
          <CardDescription>Detailed system activity and user actions</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <div className="flex space-x-2">
                <Input 
                  placeholder="Search logs..." 
                  className="max-w-sm" 
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && applyFilters()}
                />
                <select 
                  className="border rounded-md p-2"
                  value={actionFilter}
                  onChange={(e) => setActionFilter(e.target.value)}
                >
                  <option>All Actions</option>
                  <option>Login/Logout</option>
                  <option>Data Changes</option>
                  <option>System Config</option>
                  <option>Failed Actions</option>
                </select>
                <Button variant="outline" onClick={applyFilters}>
                  Apply Filters
                </Button>
              </div>
              <div className="flex space-x-2">
                <Button variant="outline" onClick={handleFilterByDate}>
                  Filter by Date
                </Button>
                <Button variant="outline" onClick={handleExportLogs}>
                  Export Logs
                </Button>
              </div>
            </div>
            <div className="border rounded-lg">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Log ID</TableHead>
                    <TableHead>User</TableHead>
                    <TableHead>Action</TableHead>
                    <TableHead>Resource</TableHead>
                    <TableHead>IP Address</TableHead>
                    <TableHead>Timestamp</TableHead>
                    <TableHead>Status</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredLogs.map((log, index) => (
                    <TableRow key={index}>
                      <TableCell className="font-mono text-sm">{log.id}</TableCell>
                      <TableCell>{log.user}</TableCell>
                      <TableCell>{log.action}</TableCell>
                      <TableCell>{log.resource}</TableCell>
                      <TableCell className="font-mono">{log.ip}</TableCell>
                      <TableCell>{log.timestamp}</TableCell>
                      <TableCell>
                        <Badge variant={log.status === "Success" ? "default" : "destructive"}>
                          {log.status}
                        </Badge>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          </div>
        </CardContent>
      </Card>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-6">
        <Card>
          <CardHeader>
            <CardTitle>Compliance Reports</CardTitle>
            <CardDescription>Generate compliance and audit reports</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <Button 
              variant="outline" 
              className="w-full justify-start"
              onClick={() => handleGenerateReport("SOX Compliance Report")}
            >
              Generate SOX Compliance Report
            </Button>
            <Button 
              variant="outline" 
              className="w-full justify-start"
              onClick={() => handleGenerateReport("GDPR Activity Report")}
            >
              Generate GDPR Activity Report
            </Button>
            <Button 
              variant="outline" 
              className="w-full justify-start"
              onClick={() => handleGenerateReport("Security Audit Report")}
            >
              Generate Security Audit Report
            </Button>
            <Button 
              variant="outline" 
              className="w-full justify-start"
              onClick={() => handleGenerateReport("User Activity Report")}
            >
              Generate User Activity Report
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Data Retention</CardTitle>
            <CardDescription>Configure log retention policies</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex justify-between">
              <span>Current Storage</span>
              <span className="font-bold">2.3 GB</span>
            </div>
            <div className="flex justify-between">
              <span>Retention Period</span>
              <span className="font-bold">{retentionSettings.period} days</span>
            </div>
            <div className="flex justify-between">
              <span>Auto Archive</span>
              <span className={`font-bold ${retentionSettings.autoArchive ? 'text-green-600' : 'text-red-600'}`}>
                {retentionSettings.autoArchive ? 'Enabled' : 'Disabled'}
              </span>
            </div>
            <div className="flex justify-between">
              <span>Compression</span>
              <span className={`font-bold ${retentionSettings.compression ? 'text-green-600' : 'text-red-600'}`}>
                {retentionSettings.compression ? 'Enabled' : 'Disabled'}
              </span>
            </div>
            
            <AlertDialog open={isRetentionDialogOpen} onOpenChange={setIsRetentionDialogOpen}>
              <AlertDialogTrigger asChild>
                <Button variant="outline" className="w-full">
                  Configure Retention
                </Button>
              </AlertDialogTrigger>
              <AlertDialogContent>
                <AlertDialogHeader>
                  <AlertDialogTitle>Configure Retention Settings</AlertDialogTitle>
                  <AlertDialogDescription>
                    Adjust data retention policies for audit logs
                  </AlertDialogDescription>
                </AlertDialogHeader>
                <div className="space-y-4 py-4">
                  <div>
                    <label className="text-sm font-medium">Retention Period (days)</label>
                    <Input
                      type="number"
                      value={retentionSettings.period}
                      onChange={(e) => setRetentionSettings(prev => ({
                        ...prev,
                        period: e.target.value
                      }))}
                      placeholder="90"
                    />
                  </div>
                  <div className="flex items-center space-x-2">
                    <input
                      type="checkbox"
                      id="autoArchive"
                      checked={retentionSettings.autoArchive}
                      onChange={(e) => setRetentionSettings(prev => ({
                        ...prev,
                        autoArchive: e.target.checked
                      }))}
                    />
                    <label htmlFor="autoArchive" className="text-sm">Enable Auto Archive</label>
                  </div>
                  <div className="flex items-center space-x-2">
                    <input
                      type="checkbox"
                      id="compression"
                      checked={retentionSettings.compression}
                      onChange={(e) => setRetentionSettings(prev => ({
                        ...prev,
                        compression: e.target.checked
                      }))}
                    />
                    <label htmlFor="compression" className="text-sm">Enable Compression</label>
                  </div>
                </div>
                <AlertDialogFooter>
                  <AlertDialogCancel>Cancel</AlertDialogCancel>
                  <AlertDialogAction onClick={handleRetentionSave}>
                    Save Settings
                  </AlertDialogAction>
                </AlertDialogFooter>
              </AlertDialogContent>
            </AlertDialog>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default AuditLogs;
