
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { QrCode, RefreshCw, Download } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { useState } from "react";

const CustomerSettings = () => {
  const { toast } = useToast();
  const [qrCodeData, setQrCodeData] = useState("voiceflow://login?token=customer123&server=demo.voiceflow.com&expires=1735689600");

  const generateQRCode = () => {
    // Generate new QR code with fresh token
    const newToken = Math.random().toString(36).substring(2, 15);
    const expiresAt = Date.now() + (24 * 60 * 60 * 1000); // 24 hours from now
    const newQRData = `voiceflow://login?token=${newToken}&server=demo.voiceflow.com&expires=${expiresAt}`;
    setQrCodeData(newQRData);
    
    toast({
      title: "QR Code Generated",
      description: "New QR code has been generated for mobile app login.",
    });
  };

  const downloadQRCode = () => {
    // Create canvas and generate QR code image for download
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    canvas.width = 200;
    canvas.height = 200;
    
    if (ctx) {
      // Simple QR code pattern simulation for demo
      ctx.fillStyle = '#000000';
      ctx.fillRect(0, 0, 200, 200);
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(10, 10, 180, 180);
      
      // Create download link
      const link = document.createElement('a');
      link.download = 'voiceflow-login-qr.png';
      link.href = canvas.toDataURL();
      link.click();
    }
    
    toast({
      title: "QR Code Downloaded",
      description: "QR code image has been saved to your downloads.",
    });
  };

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
            <CardTitle>Mobile App Login</CardTitle>
            <CardDescription>Scan QR code to login to VoiceFlow mobile app</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex flex-col items-center space-y-4">
              <div className="w-48 h-48 border-2 border-dashed border-gray-300 rounded-lg flex items-center justify-center bg-gray-50">
                <div className="text-center">
                  <QrCode className="h-16 w-16 text-gray-400 mx-auto mb-2" />
                  <p className="text-sm text-gray-500">QR Code for Mobile Login</p>
                  <p className="text-xs text-gray-400 mt-1">Scan with VoiceFlow app</p>
                </div>
              </div>
              <div className="text-xs text-gray-500 max-w-48 break-all font-mono bg-gray-100 p-2 rounded">
                {qrCodeData}
              </div>
              <div className="flex space-x-2">
                <Button 
                  variant="outline" 
                  size="sm"
                  onClick={generateQRCode}
                  className="flex items-center space-x-1"
                >
                  <RefreshCw className="h-4 w-4" />
                  <span>Regenerate</span>
                </Button>
                <Button 
                  variant="outline" 
                  size="sm"
                  onClick={downloadQRCode}
                  className="flex items-center space-x-1"
                >
                  <Download className="h-4 w-4" />
                  <span>Download</span>
                </Button>
              </div>
              <div className="text-xs text-gray-500 text-center">
                <p>• QR code expires in 24 hours</p>
                <p>• Use VoiceFlow mobile app to scan</p>
                <p>• Regenerate if code expires</p>
              </div>
            </div>
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
