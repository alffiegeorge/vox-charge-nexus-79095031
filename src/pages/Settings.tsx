
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";

const Settings = () => {
  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">System Settings</h1>
        <p className="text-gray-600">Configure system preferences and settings</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>General Settings</CardTitle>
            <CardDescription>Basic system configuration</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label>Company Name</Label>
              <Input placeholder="VoiceFlow Communications" />
            </div>
            <div className="space-y-2">
              <Label>System Email</Label>
              <Input placeholder="admin@voiceflow.com" />
            </div>
            <div className="space-y-2">
              <Label>Currency</Label>
              <select className="w-full border rounded-md p-2">
                <option>USD ($)</option>
                <option>EUR (€)</option>
                <option>GBP (£)</option>
              </select>
            </div>
            <div className="space-y-2">
              <Label>Timezone</Label>
              <select className="w-full border rounded-md p-2">
                <option>America/New_York</option>
                <option>Europe/London</option>
                <option>Asia/Tokyo</option>
              </select>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Billing Settings</CardTitle>
            <CardDescription>Configure billing and payment options</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label>Minimum Credit</Label>
              <Input placeholder="5.00" />
            </div>
            <div className="space-y-2">
              <Label>Low Balance Warning</Label>
              <Input placeholder="10.00" />
            </div>
            <div className="flex items-center justify-between">
              <Label>Auto-suspend on Zero Balance</Label>
              <Switch />
            </div>
            <div className="flex items-center justify-between">
              <Label>Email Notifications</Label>
              <Switch />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Asterisk Configuration</CardTitle>
            <CardDescription>Asterisk core settings</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label>Asterisk Server IP</Label>
              <Input placeholder="192.168.1.100" />
            </div>
            <div className="space-y-2">
              <Label>AMI Port</Label>
              <Input placeholder="5038" />
            </div>
            <div className="space-y-2">
              <Label>AMI Username</Label>
              <Input placeholder="admin" />
            </div>
            <div className="space-y-2">
              <Label>AMI Password</Label>
              <Input type="password" placeholder="********" />
            </div>
            <Button variant="outline" className="w-full">Test Connection</Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Security Settings</CardTitle>
            <CardDescription>System security configuration</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label>Session Timeout (minutes)</Label>
              <Input placeholder="30" />
            </div>
            <div className="flex items-center justify-between">
              <Label>Force Password Change</Label>
              <Switch />
            </div>
            <div className="flex items-center justify-between">
              <Label>Two-Factor Authentication</Label>
              <Switch />
            </div>
            <div className="flex items-center justify-between">
              <Label>Login Attempt Limit</Label>
              <Switch />
            </div>
            <div className="space-y-2">
              <Label>Max Login Attempts</Label>
              <Input placeholder="5" />
            </div>
          </CardContent>
        </Card>
      </div>

      <Card className="mt-6">
        <CardHeader>
          <CardTitle>System Backup</CardTitle>
          <CardDescription>Backup and restore system data</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-4">
              <h4 className="font-medium">Database Backup</h4>
              <p className="text-sm text-gray-600">Create a backup of the system database</p>
              <Button className="w-full bg-blue-600 hover:bg-blue-700">Create Backup</Button>
            </div>
            <div className="space-y-4">
              <h4 className="font-medium">Restore System</h4>
              <p className="text-sm text-gray-600">Restore from a previous backup</p>
              <Input type="file" className="mb-2" />
              <Button variant="outline" className="w-full">Restore Backup</Button>
            </div>
          </div>
        </CardContent>
      </Card>

      <div className="mt-6 flex justify-end space-x-4">
        <Button variant="outline">Cancel</Button>
        <Button className="bg-green-600 hover:bg-green-700">Save All Settings</Button>
      </div>
    </div>
  );
};

export default Settings;
