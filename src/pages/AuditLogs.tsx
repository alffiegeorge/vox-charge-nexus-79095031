
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";

const DUMMY_LOGS = [
  { id: "LOG-001", user: "admin", action: "Customer Created", resource: "Customer C005", ip: "192.168.1.100", timestamp: "2024-01-05 14:32:15", status: "Success" },
  { id: "LOG-002", user: "sarah.johnson", action: "Rate Updated", resource: "Rate R123", ip: "192.168.1.105", timestamp: "2024-01-05 14:30:42", status: "Success" },
  { id: "LOG-003", user: "mike.wilson", action: "Login Failed", resource: "Admin Panel", ip: "192.168.1.110", timestamp: "2024-01-05 14:28:33", status: "Failed" },
  { id: "LOG-004", user: "admin", action: "DID Assigned", resource: "DID +1-555-0123", ip: "192.168.1.100", timestamp: "2024-01-05 14:25:17", status: "Success" },
  { id: "LOG-005", user: "lisa.davis", action: "Invoice Generated", resource: "Invoice INV-2024-005", ip: "192.168.1.115", timestamp: "2024-01-05 14:22:08", status: "Success" }
];

const AuditLogs = () => {
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
              <Button size="sm" variant="outline">Block IP</Button>
            </div>
            <div className="flex items-center justify-between p-3 border rounded bg-yellow-50">
              <div>
                <div className="font-medium text-yellow-800">Unusual Admin Activity</div>
                <div className="text-sm text-yellow-600">Bulk customer deletion by admin user</div>
                <div className="text-xs text-yellow-500">2024-01-05 13:45:00</div>
              </div>
              <Button size="sm" variant="outline">Review</Button>
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
                <Input placeholder="Search logs..." className="max-w-sm" />
                <select className="border rounded-md p-2">
                  <option>All Actions</option>
                  <option>Login/Logout</option>
                  <option>Data Changes</option>
                  <option>System Config</option>
                  <option>Failed Actions</option>
                </select>
              </div>
              <div className="flex space-x-2">
                <Button variant="outline">Filter by Date</Button>
                <Button variant="outline">Export Logs</Button>
              </div>
            </div>
            <div className="border rounded-lg">
              <table className="w-full">
                <thead className="border-b bg-gray-50">
                  <tr>
                    <th className="text-left p-4">Log ID</th>
                    <th className="text-left p-4">User</th>
                    <th className="text-left p-4">Action</th>
                    <th className="text-left p-4">Resource</th>
                    <th className="text-left p-4">IP Address</th>
                    <th className="text-left p-4">Timestamp</th>
                    <th className="text-left p-4">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {DUMMY_LOGS.map((log, index) => (
                    <tr key={index} className="border-b hover:bg-gray-50">
                      <td className="p-4 font-mono text-sm">{log.id}</td>
                      <td className="p-4">{log.user}</td>
                      <td className="p-4">{log.action}</td>
                      <td className="p-4">{log.resource}</td>
                      <td className="p-4 font-mono">{log.ip}</td>
                      <td className="p-4">{log.timestamp}</td>
                      <td className="p-4">
                        <Badge variant={log.status === "Success" ? "default" : "destructive"}>
                          {log.status}
                        </Badge>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
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
            <Button variant="outline" className="w-full justify-start">
              Generate SOX Compliance Report
            </Button>
            <Button variant="outline" className="w-full justify-start">
              Generate GDPR Activity Report
            </Button>
            <Button variant="outline" className="w-full justify-start">
              Generate Security Audit Report
            </Button>
            <Button variant="outline" className="w-full justify-start">
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
              <span className="font-bold">90 days</span>
            </div>
            <div className="flex justify-between">
              <span>Auto Archive</span>
              <span className="font-bold text-green-600">Enabled</span>
            </div>
            <div className="flex justify-between">
              <span>Compression</span>
              <span className="font-bold text-green-600">Enabled</span>
            </div>
            <Button variant="outline" className="w-full">Configure Retention</Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default AuditLogs;
