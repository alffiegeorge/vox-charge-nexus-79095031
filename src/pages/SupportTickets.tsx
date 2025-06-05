
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Label } from "@/components/ui/label";

const DUMMY_TICKETS = [
  { id: "TKT-001", customer: "TechCorp Ltd", subject: "Call quality issues", priority: "High", status: "Open", agent: "John Smith", created: "2024-01-05 10:30", updated: "2024-01-05 14:20" },
  { id: "TKT-002", customer: "Global Comm", subject: "Billing discrepancy", priority: "Medium", status: "In Progress", agent: "Sarah Johnson", created: "2024-01-04 15:45", updated: "2024-01-05 09:15" },
  { id: "TKT-003", customer: "StartUp Inc", subject: "DID configuration help", priority: "Low", status: "Resolved", agent: "Mike Wilson", created: "2024-01-03 11:20", updated: "2024-01-04 16:30" },
  { id: "TKT-004", customer: "Enterprise Solutions", subject: "Service outage report", priority: "Critical", status: "Open", agent: "Lisa Davis", created: "2024-01-05 08:15", updated: "2024-01-05 08:15" }
];

const SupportTickets = () => {
  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Support Tickets</h1>
        <p className="text-gray-600">Manage customer support tickets and internal issues</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle>Open Tickets</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-red-600">12</div>
            <p className="text-sm text-gray-600">Requiring attention</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>In Progress</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-orange-600">8</div>
            <p className="text-sm text-gray-600">Being worked on</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Resolved Today</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-600">15</div>
            <p className="text-sm text-gray-600">Closed tickets</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Avg Response</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-blue-600">2.5h</div>
            <p className="text-sm text-gray-600">Response time</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle>Create New Ticket</CardTitle>
            <CardDescription>Log a new support ticket</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label>Customer</Label>
              <select className="w-full border rounded-md p-2">
                <option>Select Customer</option>
                <option>TechCorp Ltd</option>
                <option>Global Communications</option>
                <option>StartUp Inc</option>
              </select>
            </div>
            <div className="space-y-2">
              <Label>Subject</Label>
              <Input placeholder="Brief description of the issue" />
            </div>
            <div className="space-y-2">
              <Label>Priority</Label>
              <select className="w-full border rounded-md p-2">
                <option>Low</option>
                <option>Medium</option>
                <option>High</option>
                <option>Critical</option>
              </select>
            </div>
            <div className="space-y-2">
              <Label>Category</Label>
              <select className="w-full border rounded-md p-2">
                <option>Technical Support</option>
                <option>Billing</option>
                <option>Account Management</option>
                <option>Service Request</option>
              </select>
            </div>
            <div className="space-y-2">
              <Label>Description</Label>
              <Textarea placeholder="Detailed description of the issue" rows={4} />
            </div>
            <Button className="w-full bg-blue-600 hover:bg-blue-700">Create Ticket</Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Quick Actions</CardTitle>
            <CardDescription>Common support actions</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <Button variant="outline" className="w-full justify-start">
              <span className="mr-2">📞</span>
              Call Customer Back
            </Button>
            <Button variant="outline" className="w-full justify-start">
              <span className="mr-2">📧</span>
              Send Email Update
            </Button>
            <Button variant="outline" className="w-full justify-start">
              <span className="mr-2">🔄</span>
              Escalate Ticket
            </Button>
            <Button variant="outline" className="w-full justify-start">
              <span className="mr-2">📋</span>
              View Knowledge Base
            </Button>
            <Button variant="outline" className="w-full justify-start">
              <span className="mr-2">👥</span>
              Assign to Team
            </Button>
            <Button variant="outline" className="w-full justify-start">
              <span className="mr-2">📊</span>
              Generate Report
            </Button>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Support Tickets</CardTitle>
          <CardDescription>Manage all customer support tickets</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <Input placeholder="Search tickets..." className="max-w-sm" />
              <div className="flex space-x-2">
                <Button variant="outline">Filter</Button>
                <Button variant="outline">Export</Button>
              </div>
            </div>
            <div className="border rounded-lg">
              <table className="w-full">
                <thead className="border-b bg-gray-50">
                  <tr>
                    <th className="text-left p-4">Ticket ID</th>
                    <th className="text-left p-4">Customer</th>
                    <th className="text-left p-4">Subject</th>
                    <th className="text-left p-4">Priority</th>
                    <th className="text-left p-4">Status</th>
                    <th className="text-left p-4">Agent</th>
                    <th className="text-left p-4">Created</th>
                    <th className="text-left p-4">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {DUMMY_TICKETS.map((ticket, index) => (
                    <tr key={index} className="border-b">
                      <td className="p-4 font-mono">{ticket.id}</td>
                      <td className="p-4">{ticket.customer}</td>
                      <td className="p-4">{ticket.subject}</td>
                      <td className="p-4">
                        <Badge variant={
                          ticket.priority === "Critical" ? "destructive" :
                          ticket.priority === "High" ? "destructive" :
                          ticket.priority === "Medium" ? "secondary" :
                          "outline"
                        }>
                          {ticket.priority}
                        </Badge>
                      </td>
                      <td className="p-4">
                        <Badge variant={
                          ticket.status === "Resolved" ? "default" :
                          ticket.status === "In Progress" ? "secondary" :
                          "outline"
                        }>
                          {ticket.status}
                        </Badge>
                      </td>
                      <td className="p-4">{ticket.agent}</td>
                      <td className="p-4">{ticket.created}</td>
                      <td className="p-4">
                        <Button variant="outline" size="sm">View</Button>
                      </td>
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

export default SupportTickets;
