
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useToast } from "@/hooks/use-toast";
import { useState } from "react";

const Settings = () => {
  const { toast } = useToast();
  
  // General Settings State
  const [generalSettings, setGeneralSettings] = useState({
    companyName: "VoiceFlow Communications",
    systemEmail: "admin@voiceflow.com",
    currency: "VUV",
    timezone: "Pacific/Efate"
  });

  // Billing Settings State
  const [billingSettings, setBillingSettings] = useState({
    minimumCredit: "5.00",
    lowBalanceWarning: "10.00",
    autoSuspend: false,
    emailNotifications: true
  });

  // Asterisk Settings State
  const [asteriskSettings, setAsteriskSettings] = useState({
    serverIP: "192.168.1.100",
    amiPort: "5038",
    amiUsername: "admin",
    amiPassword: ""
  });

  // Security Settings State
  const [securitySettings, setSecuritySettings] = useState({
    sessionTimeout: "30",
    forcePasswordChange: false,
    twoFactorAuth: false,
    loginAttemptLimit: true,
    maxLoginAttempts: "5"
  });

  const [backupFile, setBackupFile] = useState<File | null>(null);

  const handleGeneralSettingsChange = (field: string, value: string) => {
    setGeneralSettings(prev => ({ ...prev, [field]: value }));
  };

  const handleBillingSettingsChange = (field: string, value: string | boolean) => {
    setBillingSettings(prev => ({ ...prev, [field]: value }));
  };

  const handleAsteriskSettingsChange = (field: string, value: string) => {
    setAsteriskSettings(prev => ({ ...prev, [field]: value }));
  };

  const handleSecuritySettingsChange = (field: string, value: string | boolean) => {
    setSecuritySettings(prev => ({ ...prev, [field]: value }));
  };

  const handleTestConnection = async () => {
    try {
      // Simulate connection test
      await new Promise(resolve => setTimeout(resolve, 2000));
      toast({
        title: "Connection Test",
        description: "Successfully connected to Asterisk server!",
      });
    } catch (error) {
      toast({
        title: "Connection Failed",
        description: "Unable to connect to Asterisk server. Please check your settings.",
        variant: "destructive",
      });
    }
  };

  const handleCreateBackup = async () => {
    try {
      // Simulate backup creation
      await new Promise(resolve => setTimeout(resolve, 3000));
      toast({
        title: "Backup Created",
        description: "Database backup has been created successfully.",
      });
    } catch (error) {
      toast({
        title: "Backup Failed",
        description: "Failed to create database backup.",
        variant: "destructive",
      });
    }
  };

  const handleRestoreBackup = async () => {
    if (!backupFile) {
      toast({
        title: "No File Selected",
        description: "Please select a backup file to restore.",
        variant: "destructive",
      });
      return;
    }

    try {
      // Simulate restore process
      await new Promise(resolve => setTimeout(resolve, 4000));
      toast({
        title: "Restore Complete",
        description: "System has been restored from backup successfully.",
      });
      setBackupFile(null);
    } catch (error) {
      toast({
        title: "Restore Failed",
        description: "Failed to restore from backup file.",
        variant: "destructive",
      });
    }
  };

  const handleSaveAllSettings = async () => {
    try {
      // Simulate saving all settings
      await new Promise(resolve => setTimeout(resolve, 2000));
      toast({
        title: "Settings Saved",
        description: "All system settings have been saved successfully.",
      });
    } catch (error) {
      toast({
        title: "Save Failed",
        description: "Failed to save system settings.",
        variant: "destructive",
      });
    }
  };

  const handleCancel = () => {
    // Reset all settings to initial values
    setGeneralSettings({
      companyName: "VoiceFlow Communications",
      systemEmail: "admin@voiceflow.com",
      currency: "VUV",
      timezone: "Pacific/Efate"
    });
    setBillingSettings({
      minimumCredit: "5.00",
      lowBalanceWarning: "10.00",
      autoSuspend: false,
      emailNotifications: true
    });
    setAsteriskSettings({
      serverIP: "192.168.1.100",
      amiPort: "5038",
      amiUsername: "admin",
      amiPassword: ""
    });
    setSecuritySettings({
      sessionTimeout: "30",
      forcePasswordChange: false,
      twoFactorAuth: false,
      loginAttemptLimit: true,
      maxLoginAttempts: "5"
    });
    
    toast({
      title: "Settings Reset",
      description: "All settings have been reset to default values.",
    });
  };

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
              <Input 
                value={generalSettings.companyName}
                onChange={(e) => handleGeneralSettingsChange('companyName', e.target.value)}
                placeholder="VoiceFlow Communications" 
              />
            </div>
            <div className="space-y-2">
              <Label>System Email</Label>
              <Input 
                value={generalSettings.systemEmail}
                onChange={(e) => handleGeneralSettingsChange('systemEmail', e.target.value)}
                placeholder="admin@voiceflow.com" 
              />
            </div>
            <div className="space-y-2">
              <Label>Currency</Label>
              <Select value={generalSettings.currency} onValueChange={(value) => handleGeneralSettingsChange('currency', value)}>
                <SelectTrigger>
                  <SelectValue placeholder="Select currency" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="VUV">VUV (Vt) - Vanuatu Vatu</SelectItem>
                  <SelectItem value="USD">USD ($) - US Dollar</SelectItem>
                  <SelectItem value="EUR">EUR (€) - Euro</SelectItem>
                  <SelectItem value="GBP">GBP (£) - British Pound</SelectItem>
                  <SelectItem value="AUD">AUD (A$) - Australian Dollar</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>Timezone</Label>
              <Select value={generalSettings.timezone} onValueChange={(value) => handleGeneralSettingsChange('timezone', value)}>
                <SelectTrigger>
                  <SelectValue placeholder="Select timezone" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="Pacific/Efate">Pacific/Efate (Vanuatu)</SelectItem>
                  <SelectItem value="America/New_York">America/New_York</SelectItem>
                  <SelectItem value="Europe/London">Europe/London</SelectItem>
                  <SelectItem value="Asia/Tokyo">Asia/Tokyo</SelectItem>
                  <SelectItem value="Australia/Sydney">Australia/Sydney</SelectItem>
                </SelectContent>
              </Select>
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
              <Input 
                value={billingSettings.minimumCredit}
                onChange={(e) => handleBillingSettingsChange('minimumCredit', e.target.value)}
                placeholder="5.00" 
              />
            </div>
            <div className="space-y-2">
              <Label>Low Balance Warning</Label>
              <Input 
                value={billingSettings.lowBalanceWarning}
                onChange={(e) => handleBillingSettingsChange('lowBalanceWarning', e.target.value)}
                placeholder="10.00" 
              />
            </div>
            <div className="flex items-center justify-between">
              <Label>Auto-suspend on Zero Balance</Label>
              <Switch 
                checked={billingSettings.autoSuspend}
                onCheckedChange={(checked) => handleBillingSettingsChange('autoSuspend', checked)}
              />
            </div>
            <div className="flex items-center justify-between">
              <Label>Email Notifications</Label>
              <Switch 
                checked={billingSettings.emailNotifications}
                onCheckedChange={(checked) => handleBillingSettingsChange('emailNotifications', checked)}
              />
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
              <Input 
                value={asteriskSettings.serverIP}
                onChange={(e) => handleAsteriskSettingsChange('serverIP', e.target.value)}
                placeholder="192.168.1.100" 
              />
            </div>
            <div className="space-y-2">
              <Label>AMI Port</Label>
              <Input 
                value={asteriskSettings.amiPort}
                onChange={(e) => handleAsteriskSettingsChange('amiPort', e.target.value)}
                placeholder="5038" 
              />
            </div>
            <div className="space-y-2">
              <Label>AMI Username</Label>
              <Input 
                value={asteriskSettings.amiUsername}
                onChange={(e) => handleAsteriskSettingsChange('amiUsername', e.target.value)}
                placeholder="admin" 
              />
            </div>
            <div className="space-y-2">
              <Label>AMI Password</Label>
              <Input 
                type="password" 
                value={asteriskSettings.amiPassword}
                onChange={(e) => handleAsteriskSettingsChange('amiPassword', e.target.value)}
                placeholder="********" 
              />
            </div>
            <Button 
              variant="outline" 
              className="w-full"
              onClick={handleTestConnection}
            >
              Test Connection
            </Button>
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
              <Input 
                value={securitySettings.sessionTimeout}
                onChange={(e) => handleSecuritySettingsChange('sessionTimeout', e.target.value)}
                placeholder="30" 
              />
            </div>
            <div className="flex items-center justify-between">
              <Label>Force Password Change</Label>
              <Switch 
                checked={securitySettings.forcePasswordChange}
                onCheckedChange={(checked) => handleSecuritySettingsChange('forcePasswordChange', checked)}
              />
            </div>
            <div className="flex items-center justify-between">
              <Label>Two-Factor Authentication</Label>
              <Switch 
                checked={securitySettings.twoFactorAuth}
                onCheckedChange={(checked) => handleSecuritySettingsChange('twoFactorAuth', checked)}
              />
            </div>
            <div className="flex items-center justify-between">
              <Label>Login Attempt Limit</Label>
              <Switch 
                checked={securitySettings.loginAttemptLimit}
                onCheckedChange={(checked) => handleSecuritySettingsChange('loginAttemptLimit', checked)}
              />
            </div>
            <div className="space-y-2">
              <Label>Max Login Attempts</Label>
              <Input 
                value={securitySettings.maxLoginAttempts}
                onChange={(e) => handleSecuritySettingsChange('maxLoginAttempts', e.target.value)}
                placeholder="5" 
              />
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
              <Button 
                className="w-full bg-blue-600 hover:bg-blue-700"
                onClick={handleCreateBackup}
              >
                Create Backup
              </Button>
            </div>
            <div className="space-y-4">
              <h4 className="font-medium">Restore System</h4>
              <p className="text-sm text-gray-600">Restore from a previous backup</p>
              <Input 
                type="file" 
                className="mb-2" 
                accept=".sql,.zip,.tar.gz"
                onChange={(e) => setBackupFile(e.target.files?.[0] || null)}
              />
              <Button 
                variant="outline" 
                className="w-full"
                onClick={handleRestoreBackup}
              >
                Restore Backup
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      <div className="mt-6 flex justify-end space-x-4">
        <Button 
          variant="outline"
          onClick={handleCancel}
        >
          Cancel
        </Button>
        <Button 
          className="bg-green-600 hover:bg-green-700"
          onClick={handleSaveAllSettings}
        >
          Save All Settings
        </Button>
      </div>
    </div>
  );
};

export default Settings;
