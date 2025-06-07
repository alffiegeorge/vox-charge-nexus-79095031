import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Label } from "@/components/ui/label";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { useToast } from "@/hooks/use-toast";

const DUMMY_TICKETS = [
  { id: "TKT-001", customer: "TechCorp Ltd", subject: "Call quality issues", priority: "High", status: "Open", agent: "John Smith", created: "2024-01-05 10:30", updated: "2024-01-05 14:20" },
  { id: "TKT-002", customer: "Global Comm", subject: "Billing discrepancy", priority: "Medium", status: "In Progress", agent: "Sarah Johnson", created: "2024-01-04 15:45", updated: "2024-01-05 09:15" },
  { id: "TKT-003", customer: "StartUp Inc", subject: "DID configuration help", priority: "Low", status: "Resolved", agent: "Mike Wilson", created: "2024-01-03 11:20", updated: "2024-01-04 16:30" },
  { id: "TKT-004", customer: "Enterprise Solutions", subject: "Service outage report", priority: "Critical", status: "Open", agent: "Lisa Davis", created: "2024-01-05 08:15", updated: "2024-01-05 08:15" }
];

const SupportTickets = () => {
  const { toast } = useToast();
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedTicket, setSelectedTicket] = useState<any>(null);
  const [newTicket, setNewTicket] = useState({
    customer: "",
    subject: "",
    priority: "Low",
    category: "Technical Support",
    description: ""
  });

  const handleCreateTicket = (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!newTicket.customer || !newTicket.subject || !newTicket.description) {
      toast({
        title: "Error",
        description: "Please fill in all required fields",
        variant: "destructive"
      });
      return;
    }

    console.log("Creating new ticket:", newTicket);
    toast({
      title: "Success",
      description: "Support ticket created successfully"
    });

    // Reset form
    setNewTicket({
      customer: "",
      subject: "",
      priority: "Low",
      category: "Technical Support",
      description: ""
    });
  };

  const handleQuickAction = (action: string) => {
    console.log(`Executing quick action: ${action}`);
    toast({
      title: "Action Completed",
      description: `${action} action has been executed`
    });
  };

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    console.log("Searching tickets with term:", searchTerm);
    toast({
      title: "Search",
      description: `Searching tickets for: ${searchTerm}`
    });
  };

  const handleFilter = () => {
    console.log("Opening filter options");
    toast({
      title: "Filter",
      description: "Filter options opened"
    });
  };

  const handleExport = () => {
    console.log("Exporting tickets data");
    toast({
      title: "Export",
      description: "Tickets data exported successfully"
    });
  };

  const handleViewTicket = (ticket: any) => {
    setSelectedTicket(ticket);
    console.log("Viewing ticket:", ticket.id);
  };

  const filteredTickets = DUMMY_TICKETS.filter(ticket =>
    ticket.subject.toLowerCase().includes(searchTerm.toLowerCase()) ||
    ticket.customer.toLowerCase().includes(searchTerm.toLowerCase()) ||
    ticket.id.toLowerCase().includes(searchTerm.toLowerCase())
  );

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
          <CardContent>
            <form onSubmit={handleCreateTicket} className="space-y-4">
              <div className="space-y-2">
                <Label>Customer *</Label>
                <select 
                  className="w-full border rounded-md p-2"
                  value={newTicket.customer}
                  onChange={(e) => setNewTicket({...newTicket, customer: e.target.value})}
                  required
                >
                  <option value="">Select Customer</option>
                  <option value="TechCorp Ltd">TechCorp Ltd</option>
                  <option value="Global Communications">Global Communications</option>
                  <option value="StartUp Inc">StartUp Inc</option>
                </select>
              </div>
              <div className="space-y-2">
                <Label>Subject *</Label>
                <Input 
                  placeholder="Brief description of the issue" 
                  value={newTicket.subject}
                  onChange={(e) => setNewTicket({...newTicket, subject: e.target.value})}
                  required
                />
              </div>
              <div className="space-y-2">
                <Label>Priority</Label>
                <select 
                  className="w-full border rounded-md p-2"
                  value={newTicket.priority}
                  onChange={(e) => setNewTicket({...newTicket, priority: e.target.value})}
                >
                  <option value="Low">Low</option>
                  <option value="Medium">Medium</option>
                  <option value="High">High</option>
                  <option value="Critical">Critical</option>
                </select>
              </div>
              <div className="space-y-2">
                <Label>Category</Label>
                <select 
                  className="w-full border rounded-md p-2"
                  value={newTicket.category}
                  onChange={(e) => setNewTicket({...newTicket, category: e.target.value})}
                >
                  <option value="Technical Support">Technical Support</option>
                  <option value="Billing">Billing</option>
                  <option value="Account Management">Account Management</option>
                  <option value="Service Request">Service Request</option>
                </select>
              </div>
              <div className="space-y-2">
                <Label>Description *</Label>
                <Textarea 
                  placeholder="Detailed description of the issue" 
                  rows={4}
                  value={newTicket.description}
                  onChange={(e) => setNewTicket({...newTicket, description: e.target.value})}
                  required
                />
              </div>
              <Button type="submit" className="w-full bg-blue-600 hover:bg-blue-700">
                Create Ticket
              </Button>
            </form>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Quick Actions</CardTitle>
            <CardDescription>Common support actions</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <Button 
              variant="outline" 
              className="w-full justify-start"
              onClick={() => handleQuickAction("Call Customer Back")}
            >
              <span className="mr-2">📞</span>
              Call Customer Back
            </Button>
            <Button 
              variant="outline" 
              className="w-full justify-start"
              onClick={() => handleQuickAction("Send Email Update")}
            >
              <span className="mr-2">📧</span>
              Send Email Update
            </Button>
            <Button 
              variant="outline" 
              className="w-full justify-start"
              onClick={() => handleQuickAction("Escalate Ticket")}
            >
              <span className="mr-2">🔄</span>
              Escalate Ticket
            </Button>
            <Button 
              variant="outline" 
              className="w-full justify-start"
              onClick={() => handleQuickAction("View Knowledge Base")}
            >
              <span className="mr-2">📋</span>
              View Knowledge Base
            </Button>
            <Button 
              variant="outline" 
              className="w-full justify-start"
              onClick={() => handleQuickAction("Assign to Team")}
            >
              <span className="mr-2">👥</span>
              Assign to Team
            </Button>
            <Button 
              variant="outline" 
              className="w-full justify-start"
              onClick={() => handleQuickAction("Generate Report")}
            >
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
              <form onSubmit={handleSearch} className="flex space-x-2">
                <Input 
                  placeholder="Search tickets..." 
                  className="max-w-sm"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
                <Button type="submit" variant="outline">Search</Button>
              </form>
              <div className="flex space-x-2">
                <Button variant="outline" onClick={handleFilter}>Filter</Button>
                <Button variant="outline" onClick={handleExport}>Export</Button>
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
                  {filteredTickets.map((ticket, index) => (
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
                        <Dialog>
                          <DialogTrigger asChild>
                            <Button 
                              variant="outline" 
                              size="sm"
                              onClick={() => handleViewTicket(ticket)}
                            >
                              View
                            </Button>
                          </DialogTrigger>
                          <DialogContent className="max-w-2xl">
                            <DialogHeader>
                              <DialogTitle>Ticket Details - {selectedTicket?.id}</DialogTitle>
                              <DialogDescription>
                                Complete ticket information and history
                              </DialogDescription>
                            </DialogHeader>
                            {selectedTicket && (
                              <div className="space-y-4">
                                <div className="grid grid-cols-2 gap-4">
                                  <div>
                                    <Label className="font-semibold">Customer</Label>
                                    <p>{selectedTicket.customer}</p>
                                  </div>
                                  <div>
                                    <Label className="font-semibold">Subject</Label>
                                    <p>{selectedTicket.subject}</p>
                                  </div>
                                  <div>
                                    <Label className="font-semibold">Priority</Label>
                                    <Badge variant={
                                      selectedTicket.priority === "Critical" ? "destructive" :
                                      selectedTicket.priority === "High" ? "destructive" :
                                      selectedTicket.priority === "Medium" ? "secondary" :
                                      "outline"
                                    }>
                                      {selectedTicket.priority}
                                    </Badge>
                                  </div>
                                  <div>
                                    <Label className="font-semibold">Status</Label>
                                    <Badge variant={
                                      selectedTicket.status === "Resolved" ? "default" :
                                      selectedTicket.status === "In Progress" ? "secondary" :
                                      "outline"
                                    }>
                                      {selectedTicket.status}
                                    </Badge>
                                  </div>
                                  <div>
                                    <Label className="font-semibold">Assigned Agent</Label>
                                    <p>{selectedTicket.agent}</p>
                                  </div>
                                  <div>
                                    <Label className="font-semibold">Created</Label>
                                    <p>{selectedTicket.created}</p>
                                  </div>
                                </div>
                                <div className="space-y-2">
                                  <Label className="font-semibold">Actions</Label>
                                  <div className="flex space-x-2">
                                    <Button size="sm" onClick={() => toast({title: "Success", description: "Ticket status updated"})}>
                                      Update Status
                                    </Button>
                                    <Button size="sm" variant="outline" onClick={() => toast({title: "Success", description: "Comment added to ticket"})}>
                                      Add Comment
                                    </Button>
                                    <Button size="sm" variant="outline" onClick={() => toast({title: "Success", description: "Ticket reassigned"})}>
                                      Reassign
                                    </Button>
                                  </div>
                                </div>
                              </div>
                            )}
                          </DialogContent>
                        </Dialog>
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
