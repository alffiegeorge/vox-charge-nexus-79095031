
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";

const CustomerSettings = () => {
  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Account Settings</h1>
        <p className="text-gray-600">Manage your account preferences and settings</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Profile Information</CardTitle>
            <CardDescription>Update your personal information</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label>Full Name</Label>
              <Input placeholder="John Doe" />
            </div>
            <div className="space-y-2">
              <Label>Email Address</Label>
              <Input placeholder="john@example.com" />
            </div>
            <div className="space-y-2">
              <Label>Phone Number</Label>
              <Input placeholder="+1-555-0123" />
            </div>
            <div className="space-y-2">
              <Label>Company</Label>
              <Input placeholder="Your Company" />
            </div>
            <Button className="w-full bg-blue-600 hover:bg-blue-700">Update Profile</Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Security Settings</CardTitle>
            <CardDescription>Manage your account security</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label>Current Password</Label>
              <Input type="password" placeholder="********" />
            </div>
            <div className="space-y-2">
              <Label>New Password</Label>
              <Input type="password" placeholder="********" />
            </div>
            <div className="space-y-2">
              <Label>Confirm New Password</Label>
              <Input type="password" placeholder="********" />
            </div>
            <Button variant="outline" className="w-full">Change Password</Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Notification Preferences</CardTitle>
            <CardDescription>Configure your notification settings</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between">
              <Label>Email Notifications</Label>
              <Switch />
            </div>
            <div className="flex items-center justify-between">
              <Label>Low Balance Alerts</Label>
              <Switch />
            </div>
            <div className="flex items-center justify-between">
              <Label>Monthly Statements</Label>
              <Switch />
            </div>
            <div className="flex items-center justify-between">
              <Label>SMS Notifications</Label>
              <Switch />
            </div>
            <div className="space-y-2">
              <Label>Low Balance Threshold</Label>
              <Input placeholder="$10.00" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Call Settings</CardTitle>
            <CardDescription>Configure call preferences</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label>Default Caller ID</Label>
              <Input placeholder="+1-555-0123" />
            </div>
            <div className="flex items-center justify-between">
              <Label>Call Recording</Label>
              <Switch />
            </div>
            <div className="flex items-center justify-between">
              <Label>Call Waiting</Label>
              <Switch />
            </div>
            <div className="space-y-2">
              <Label>Voicemail Email</Label>
              <Input placeholder="john@example.com" />
            </div>
            <Button variant="outline" className="w-full">Save Call Settings</Button>
          </CardContent>
        </Card>
      </div>

      <Card className="mt-6">
        <CardHeader>
          <CardTitle>Account Actions</CardTitle>
          <CardDescription>Manage your account status</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <Button variant="outline">Download Data</Button>
            <Button variant="outline">Suspend Account</Button>
            <Button variant="destructive">Close Account</Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};

export default CustomerSettings;
