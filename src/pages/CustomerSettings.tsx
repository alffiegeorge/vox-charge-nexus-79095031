
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
  
  // Profile form state
  const [profileData, setProfileData] = useState({
    fullName: "John Doe",
    email: "john@example.com",
    phone: "+1-555-0123",
    company: "Your Company"
  });

  // Password form state
  const [passwordData, setPasswordData] = useState({
    currentPassword: "",
    newPassword: "",
    confirmPassword: ""
  });

  // Notification preferences state
  const [notifications, setNotifications] = useState({
    emailNotifications: true,
    lowBalanceAlerts: true,
    monthlyStatements: true,
    smsNotifications: false,
    lowBalanceThreshold: "10.00"
  });

  // Call settings state
  const [callSettings, setCallSettings] = useState({
    defaultCallerId: "+1-555-0123",
    callRecording: false,
    callWaiting: true,
    voicemailEmail: "john@example.com"
  });

  const handleProfileSubmit = async () => {
    try {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1500));
      toast({
        title: "Profile Updated",
        description: "Your profile information has been updated successfully.",
      });
    } catch (error) {
      toast({
        title: "Update Failed",
        description: "Failed to update profile information.",
        variant: "destructive",
      });
    }
  };

  const handlePasswordChange = async () => {
    if (!passwordData.currentPassword || !passwordData.newPassword || !passwordData.confirmPassword) {
      toast({
        title: "Missing Information",
        description: "Please fill in all password fields.",
        variant: "destructive",
      });
      return;
    }

    if (passwordData.newPassword !== passwordData.confirmPassword) {
      toast({
        title: "Password Mismatch",
        description: "New password and confirmation do not match.",
        variant: "destructive",
      });
      return;
    }

    if (passwordData.newPassword.length < 8) {
      toast({
        title: "Password Too Short",
        description: "Password must be at least 8 characters long.",
        variant: "destructive",
      });
      return;
    }

    try {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 2000));
      setPasswordData({ currentPassword: "", newPassword: "", confirmPassword: "" });
      toast({
        title: "Password Changed",
        description: "Your password has been changed successfully.",
      });
    } catch (error) {
      toast({
        title: "Password Change Failed",
        description: "Failed to change password. Please try again.",
        variant: "destructive",
      });
    }
  };

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

  const handleCallSettingsSave = async () => {
    try {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1500));
      toast({
        title: "Call Settings Saved",
        description: "Your call preferences have been updated successfully.",
      });
    } catch (error) {
      toast({
        title: "Save Failed",
        description: "Failed to save call settings.",
        variant: "destructive",
      });
    }
  };

  const handleDownloadData = async () => {
    try {
      // Simulate data preparation and download
      await new Promise(resolve => setTimeout(resolve, 3000));
      
      // Create a dummy data file for download
      const data = JSON.stringify({
        profile: profileData,
        callHistory: "Call history data would be here",
        billingHistory: "Billing history data would be here",
        exportDate: new Date().toISOString()
      }, null, 2);
      
      const blob = new Blob([data], { type: 'application/json' });
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = 'account-data.json';
      link.click();
      window.URL.revokeObjectURL(url);
      
      toast({
        title: "Data Downloaded",
        description: "Your account data has been downloaded successfully.",
      });
    } catch (error) {
      toast({
        title: "Download Failed",
        description: "Failed to download account data.",
        variant: "destructive",
      });
    }
  };

  const handleSuspendAccount = async () => {
    if (!confirm("Are you sure you want to suspend your account? This action will temporarily disable your services.")) {
      return;
    }

    try {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 2000));
      toast({
        title: "Account Suspended",
        description: "Your account has been suspended. Contact support to reactivate.",
      });
    } catch (error) {
      toast({
        title: "Suspension Failed",
        description: "Failed to suspend account. Please contact support.",
        variant: "destructive",
      });
    }
  };

  const handleCloseAccount = async () => {
    if (!confirm("Are you sure you want to permanently close your account? This action cannot be undone and will delete all your data.")) {
      return;
    }

    const finalConfirm = prompt("Type 'DELETE' to confirm account closure:");
    if (finalConfirm !== 'DELETE') {
      toast({
        title: "Account Closure Cancelled",
        description: "Account closure has been cancelled.",
      });
      return;
    }

    try {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 3000));
      toast({
        title: "Account Closed",
        description: "Your account has been permanently closed.",
        variant: "destructive",
      });
    } catch (error) {
      toast({
        title: "Closure Failed",
        description: "Failed to close account. Please contact support.",
        variant: "destructive",
      });
    }
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
              <Input 
                value={profileData.fullName}
                onChange={(e) => setProfileData({...profileData, fullName: e.target.value})}
                placeholder="John Doe" 
              />
            </div>
            <div className="space-y-2">
              <Label>Email Address</Label>
              <Input 
                value={profileData.email}
                onChange={(e) => setProfileData({...profileData, email: e.target.value})}
                placeholder="john@example.com" 
              />
            </div>
            <div className="space-y-2">
              <Label>Phone Number</Label>
              <Input 
                value={profileData.phone}
                onChange={(e) => setProfileData({...profileData, phone: e.target.value})}
                placeholder="+1-555-0123" 
              />
            </div>
            <div className="space-y-2">
              <Label>Company</Label>
              <Input 
                value={profileData.company}
                onChange={(e) => setProfileData({...profileData, company: e.target.value})}
                placeholder="Your Company" 
              />
            </div>
            <Button 
              className="w-full bg-blue-600 hover:bg-blue-700"
              onClick={handleProfileSubmit}
            >
              Update Profile
            </Button>
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
              <Input 
                type="password" 
                value={passwordData.currentPassword}
                onChange={(e) => setPasswordData({...passwordData, currentPassword: e.target.value})}
                placeholder="********" 
              />
            </div>
            <div className="space-y-2">
              <Label>New Password</Label>
              <Input 
                type="password" 
                value={passwordData.newPassword}
                onChange={(e) => setPasswordData({...passwordData, newPassword: e.target.value})}
                placeholder="********" 
              />
            </div>
            <div className="space-y-2">
              <Label>Confirm New Password</Label>
              <Input 
                type="password" 
                value={passwordData.confirmPassword}
                onChange={(e) => setPasswordData({...passwordData, confirmPassword: e.target.value})}
                placeholder="********" 
              />
            </div>
            <Button 
              variant="outline" 
              className="w-full"
              onClick={handlePasswordChange}
            >
              Change Password
            </Button>
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
              <Switch 
                checked={notifications.emailNotifications}
                onCheckedChange={(checked) => setNotifications({...notifications, emailNotifications: checked})}
              />
            </div>
            <div className="flex items-center justify-between">
              <Label>Low Balance Alerts</Label>
              <Switch 
                checked={notifications.lowBalanceAlerts}
                onCheckedChange={(checked) => setNotifications({...notifications, lowBalanceAlerts: checked})}
              />
            </div>
            <div className="flex items-center justify-between">
              <Label>Monthly Statements</Label>
              <Switch 
                checked={notifications.monthlyStatements}
                onCheckedChange={(checked) => setNotifications({...notifications, monthlyStatements: checked})}
              />
            </div>
            <div className="flex items-center justify-between">
              <Label>SMS Notifications</Label>
              <Switch 
                checked={notifications.smsNotifications}
                onCheckedChange={(checked) => setNotifications({...notifications, smsNotifications: checked})}
              />
            </div>
            <div className="space-y-2">
              <Label>Low Balance Threshold</Label>
              <Input 
                value={notifications.lowBalanceThreshold}
                onChange={(e) => setNotifications({...notifications, lowBalanceThreshold: e.target.value})}
                placeholder="$10.00" 
              />
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
              <Input 
                value={callSettings.defaultCallerId}
                onChange={(e) => setCallSettings({...callSettings, defaultCallerId: e.target.value})}
                placeholder="+1-555-0123" 
              />
            </div>
            <div className="flex items-center justify-between">
              <Label>Call Recording</Label>
              <Switch 
                checked={callSettings.callRecording}
                onCheckedChange={(checked) => setCallSettings({...callSettings, callRecording: checked})}
              />
            </div>
            <div className="flex items-center justify-between">
              <Label>Call Waiting</Label>
              <Switch 
                checked={callSettings.callWaiting}
                onCheckedChange={(checked) => setCallSettings({...callSettings, callWaiting: checked})}
              />
            </div>
            <div className="space-y-2">
              <Label>Voicemail Email</Label>
              <Input 
                value={callSettings.voicemailEmail}
                onChange={(e) => setCallSettings({...callSettings, voicemailEmail: e.target.value})}
                placeholder="john@example.com" 
              />
            </div>
            <Button 
              variant="outline" 
              className="w-full"
              onClick={handleCallSettingsSave}
            >
              Save Call Settings
            </Button>
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
            <Button 
              variant="outline"
              onClick={handleDownloadData}
            >
              Download Data
            </Button>
            <Button 
              variant="outline"
              onClick={handleSuspendAccount}
            >
              Suspend Account
            </Button>
            <Button 
              variant="destructive"
              onClick={handleCloseAccount}
            >
              Close Account
            </Button>
          </div>
        </CardContent>
      </div>
    </div>
  );
};

export default CustomerSettings;
