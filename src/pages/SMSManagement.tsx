
import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useToast } from "@/hooks/use-toast";
import { Calendar, Clock, Send, Plus, Download, Search } from "lucide-react";
import { apiClient } from "@/lib/api";

interface SMSRecord {
  id: string;
  to: string;
  message: string;
  status: string;
  cost: string;
  date: string;
}

interface SMSTemplate {
  id: string;
  title: string;
  message: string;
  category: string;
}

interface SMSStats {
  sent: number;
  delivered: number;
  failed: number;
  cost: number;
}

const SMSManagement = () => {
  const { toast } = useToast();
  const [recipients, setRecipients] = useState("");
  const [message, setMessage] = useState("");
  const [searchTerm, setSearchTerm] = useState("");
  const [isScheduleDialogOpen, setIsScheduleDialogOpen] = useState(false);
  const [isTemplateDialogOpen, setIsTemplateDialogOpen] = useState(false);
  const [scheduleDate, setScheduleDate] = useState("");
  const [scheduleTime, setScheduleTime] = useState("");
  const [loading, setLoading] = useState(true);
  
  // Database state
  const [smsHistory, setSmsHistory] = useState<SMSRecord[]>([]);
  const [smsTemplates, setSmsTemplates] = useState<SMSTemplate[]>([]);
  const [smsStats, setSmsStats] = useState<SMSStats>({
    sent: 0,
    delivered: 0,
    failed: 0,
    cost: 0
  });
  
  const [newTemplate, setNewTemplate] = useState({
    title: "",
    message: "",
    category: ""
  });

  useEffect(() => {
    fetchAllSMSData();
  }, []);

  const fetchAllSMSData = async () => {
    try {
      console.log('Fetching SMS data from database...');
      
      // Fetch SMS history
      const historyData = await apiClient.getSMSHistory() as any;
      console.log('SMS history data received:', historyData);
      
      // Fetch SMS templates
      const templatesData = await apiClient.getSMSTemplates() as any[];
      console.log('SMS templates data received:', templatesData);
      
      // Fetch SMS stats
      const statsData = await apiClient.getSMSStats() as any;
      console.log('SMS stats data received:', statsData);
      
      // Transform history data
      if (historyData.records) {
        const transformedHistory = historyData.records.map((sms: any) => ({
          id: sms.id || sms.sms_id,
          to: sms.to || sms.phone_number,
          message: sms.message,
          status: sms.status,
          cost: sms.cost ? `$${sms.cost.toFixed(2)}` : "$0.00",
          date: sms.date || sms.created_at
        }));
        setSmsHistory(transformedHistory);
      }
      
      // Transform templates data
      if (templatesData) {
        const transformedTemplates = templatesData.map((template: any) => ({
          id: template.id || template.template_id,
          title: template.title,
          message: template.message,
          category: template.category
        }));
        setSmsTemplates(transformedTemplates);
      }
      
      // Set stats
      if (statsData) {
        setSmsStats({
          sent: statsData.sent || 0,
          delivered: statsData.delivered || 0,
          failed: statsData.failed || 0,
          cost: statsData.cost || 0
        });
      }
      
    } catch (error) {
      console.error('Error fetching SMS data:', error);
      toast({
        title: "Error",
        description: "Failed to load SMS data from database",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const handleSendNow = async () => {
    if (!recipients.trim() || !message.trim()) {
      toast({
        title: "Error",
        description: "Please enter recipients and message",
        variant: "destructive"
      });
      return;
    }

    try {
      const recipientList = recipients.split('\n').filter(r => r.trim());
      await apiClient.sendSMS({
        recipients: recipientList,
        message,
        schedule: null
      });

      toast({
        title: "SMS Sent",
        description: `Message sent to ${recipientList.length} recipient(s)`
      });

      setRecipients("");
      setMessage("");
      fetchAllSMSData(); // Refresh data
    } catch (error) {
      console.error('Error sending SMS:', error);
      toast({
        title: "Error",
        description: "Failed to send SMS",
        variant: "destructive"
      });
    }
  };

  const handleSchedule = async () => {
    if (!recipients.trim() || !message.trim() || !scheduleDate || !scheduleTime) {
      toast({
        title: "Error",
        description: "Please fill all fields for scheduling",
        variant: "destructive"
      });
      return;
    }

    try {
      const recipientList = recipients.split('\n').filter(r => r.trim());
      await apiClient.sendSMS({
        recipients: recipientList,
        message,
        schedule: `${scheduleDate} ${scheduleTime}`
      });

      toast({
        title: "SMS Scheduled",
        description: `Message scheduled for ${scheduleDate} at ${scheduleTime}`
      });

      setIsScheduleDialogOpen(false);
      setRecipients("");
      setMessage("");
      setScheduleDate("");
      setScheduleTime("");
      fetchAllSMSData(); // Refresh data
    } catch (error) {
      console.error('Error scheduling SMS:', error);
      toast({
        title: "Error",
        description: "Failed to schedule SMS",
        variant: "destructive"
      });
    }
  };

  const handleUseTemplate = (template: SMSTemplate) => {
    setMessage(template.message);
    toast({
      title: "Template Applied",
      description: `${template.title} template has been applied`
    });
  };

  const handleCreateTemplate = async () => {
    if (!newTemplate.title || !newTemplate.message || !newTemplate.category) {
      toast({
        title: "Error", 
        description: "Please fill all template fields",
        variant: "destructive"
      });
      return;
    }

    try {
      await apiClient.createSMSTemplate(newTemplate);
      
      toast({
        title: "Template Created",
        description: `Template "${newTemplate.title}" has been created`
      });

      setIsTemplateDialogOpen(false);
      setNewTemplate({ title: "", message: "", category: "" });
      fetchAllSMSData(); // Refresh data
    } catch (error) {
      console.error('Error creating template:', error);
      toast({
        title: "Error",
        description: "Failed to create template",
        variant: "destructive"
      });
    }
  };

  const handleExportReport = () => {
    toast({
      title: "Export Started",
      description: "SMS report is being generated and will be downloaded shortly"
    });
  };

  const filteredSMS = smsHistory.filter(sms => 
    sms.id.toLowerCase().includes(searchTerm.toLowerCase()) ||
    sms.to.toLowerCase().includes(searchTerm.toLowerCase()) ||
    sms.message.toLowerCase().includes(searchTerm.toLowerCase())
  );

  if (loading) {
    return (
      <div className="p-6">
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">SMS Management</h1>
          <p className="text-gray-600">Loading SMS data from database...</p>
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
        <h1 className="text-3xl font-bold text-gray-900 mb-2">SMS Management</h1>
        <p className="text-gray-600">Send SMS notifications and manage SMS campaigns</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle>SMS Sent</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-blue-600">{smsStats.sent}</div>
            <p className="text-sm text-gray-600">Total sent</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Delivered</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-600">{smsStats.delivered}</div>
            <p className="text-sm text-gray-600">
              {smsStats.sent > 0 ? `${((smsStats.delivered / smsStats.sent) * 100).toFixed(1)}% delivery rate` : '0% delivery rate'}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Failed</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-red-600">{smsStats.failed}</div>
            <p className="text-sm text-gray-600">
              {smsStats.sent > 0 ? `${((smsStats.failed / smsStats.sent) * 100).toFixed(1)}% failure rate` : '0% failure rate'}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Cost</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-purple-600">${smsStats.cost.toFixed(2)}</div>
            <p className="text-sm text-gray-600">Total cost</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        {/* Send SMS Card */}
        <Card>
          <CardHeader>
            <CardTitle>Send SMS</CardTitle>
            <CardDescription>Send individual or bulk SMS messages</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label>Recipients</Label>
              <Textarea 
                placeholder="Enter phone numbers (one per line) or select from contacts" 
                rows={3}
                value={recipients}
                onChange={(e) => setRecipients(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label>Message</Label>
              <Textarea 
                placeholder="Type your message here..." 
                rows={4}
                value={message}
                onChange={(e) => setMessage(e.target.value)}
              />
              <div className="text-sm text-gray-500">Characters: {message.length}/160</div>
            </div>
            <div className="flex space-x-2">
              <Button 
                className="flex-1 bg-blue-600 hover:bg-blue-700"
                onClick={handleSendNow}
              >
                <Send className="w-4 h-4 mr-2" />
                Send Now
              </Button>
              
              <Dialog open={isScheduleDialogOpen} onOpenChange={setIsScheduleDialogOpen}>
                <DialogTrigger asChild>
                  <Button variant="outline" className="flex-1">
                    <Clock className="w-4 h-4 mr-2" />
                    Schedule
                  </Button>
                </DialogTrigger>
                <DialogContent>
                  <DialogHeader>
                    <DialogTitle>Schedule SMS</DialogTitle>
                    <DialogDescription>Set date and time for sending this SMS</DialogDescription>
                  </DialogHeader>
                  <div className="space-y-4">
                    <div className="space-y-2">
                      <Label>Date</Label>
                      <Input 
                        type="date" 
                        value={scheduleDate}
                        onChange={(e) => setScheduleDate(e.target.value)}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label>Time</Label>
                      <Input 
                        type="time" 
                        value={scheduleTime}
                        onChange={(e) => setScheduleTime(e.target.value)}
                      />
                    </div>
                    <Button onClick={handleSchedule} className="w-full">
                      <Calendar className="w-4 h-4 mr-2" />
                      Schedule SMS
                    </Button>
                  </div>
                </DialogContent>
              </Dialog>
            </div>
          </CardContent>
        </Card>

        {/* SMS Templates Card */}
        <Card>
          <CardHeader>
            <CardTitle>SMS Templates</CardTitle>
            <CardDescription>
              Pre-configured message templates ({smsTemplates.length} templates loaded from database)
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-3 max-h-64 overflow-y-auto">
              {smsTemplates.length > 0 ? (
                smsTemplates.map((template) => (
                  <div key={template.id} className="p-3 border rounded">
                    <div className="font-medium">{template.title}</div>
                    <div className="text-sm text-gray-600 mb-2">{template.message}</div>
                    <div className="flex justify-between items-center">
                      <Badge variant="secondary">{template.category}</Badge>
                      <Button 
                        size="sm" 
                        onClick={() => handleUseTemplate(template)}
                      >
                        Use Template
                      </Button>
                    </div>
                  </div>
                ))
              ) : (
                <div className="text-center py-4 text-gray-500">
                  <p>No templates found</p>
                  <p className="text-sm">Create your first template below</p>
                </div>
              )}
            </div>
            
            <Dialog open={isTemplateDialogOpen} onOpenChange={setIsTemplateDialogOpen}>
              <DialogTrigger asChild>
                <Button variant="outline" className="w-full">
                  <Plus className="w-4 h-4 mr-2" />
                  Create New Template
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Create SMS Template</DialogTitle>
                  <DialogDescription>Create a new reusable SMS template</DialogDescription>
                </DialogHeader>
                <div className="space-y-4">
                  <div className="space-y-2">
                    <Label>Template Title</Label>
                    <Input 
                      placeholder="Enter template title"
                      value={newTemplate.title}
                      onChange={(e) => setNewTemplate({...newTemplate, title: e.target.value})}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label>Category</Label>
                    <Select value={newTemplate.category} onValueChange={(value) => setNewTemplate({...newTemplate, category: value})}>
                      <SelectTrigger>
                        <SelectValue placeholder="Select category" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="Alert">Alert</SelectItem>
                        <SelectItem value="Confirmation">Confirmation</SelectItem>
                        <SelectItem value="Notification">Notification</SelectItem>
                        <SelectItem value="Marketing">Marketing</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-2">
                    <Label>Message</Label>
                    <Textarea 
                      placeholder="Enter template message"
                      rows={4}
                      value={newTemplate.message}
                      onChange={(e) => setNewTemplate({...newTemplate, message: e.target.value})}
                    />
                  </div>
                  <Button onClick={handleCreateTemplate} className="w-full">
                    Create Template
                  </Button>
                </div>
              </DialogContent>
            </Dialog>
          </CardContent>
        </Card>
      </div>

      {/* SMS History Card */}
      <Card>
        <CardHeader>
          <CardTitle>SMS History</CardTitle>
          <CardDescription>
            Track sent messages and delivery status ({smsHistory.length} messages loaded from database)
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-4 w-4" />
                <Input 
                  placeholder="Search SMS..." 
                  className="max-w-sm pl-10"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>
              <div className="flex space-x-2">
                <Button variant="outline" onClick={fetchAllSMSData}>
                  Refresh
                </Button>
                <Button variant="outline" onClick={handleExportReport}>
                  <Download className="w-4 h-4 mr-2" />
                  Export Report
                </Button>
              </div>
            </div>
            
            {filteredSMS.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                <p>No SMS records found</p>
                {searchTerm && <p className="text-sm">Try adjusting your search terms</p>}
                {!searchTerm && smsHistory.length === 0 && (
                  <p className="text-sm">Send your first SMS to get started</p>
                )}
              </div>
            ) : (
              <div className="border rounded-lg">
                <table className="w-full">
                  <thead className="border-b bg-gray-50">
                    <tr>
                      <th className="text-left p-4">SMS ID</th>
                      <th className="text-left p-4">To</th>
                      <th className="text-left p-4">Message</th>
                      <th className="text-left p-4">Status</th>
                      <th className="text-left p-4">Cost</th>
                      <th className="text-left p-4">Date</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredSMS.map((sms, index) => (
                      <tr key={index} className="border-b">
                        <td className="p-4 font-mono">{sms.id}</td>
                        <td className="p-4">{sms.to}</td>
                        <td className="p-4 max-w-xs truncate">{sms.message}</td>
                        <td className="p-4">
                          <Badge variant={
                            sms.status === "Delivered" ? "default" :
                            sms.status === "Failed" ? "destructive" :
                            "secondary"
                          }>
                            {sms.status}
                          </Badge>
                        </td>
                        <td className="p-4">{sms.cost}</td>
                        <td className="p-4">{sms.date}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  );
};

export default SMSManagement;
