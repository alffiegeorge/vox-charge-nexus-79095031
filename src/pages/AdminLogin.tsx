
import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Phone, Shield } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { useNavigate } from "react-router-dom";
import { apiClient } from "@/lib/api";

const AdminLogin = () => {
  const [loginData, setLoginData] = useState({ username: "", password: "" });
  const [isLoading, setIsLoading] = useState(false);
  const { toast } = useToast();
  const navigate = useNavigate();

  const handleLogin = async () => {
    if (!loginData.username || !loginData.password) {
      toast({
        title: "Login Failed",
        description: "Please enter both username and password",
        variant: "destructive"
      });
      return;
    }

    setIsLoading(true);

    try {
      console.log('Admin login attempt with:', { username: loginData.username });
      
      const response = await apiClient.login({
        username: loginData.username,
        password: loginData.password
      });

      console.log('Admin login response:', response);

      // Check if user is admin
      if (response.user.role !== "admin") {
        toast({
          title: "Access Denied",
          description: "This login is for administrators only",
          variant: "destructive"
        });
        return;
      }

      // Store authentication token
      localStorage.setItem('authToken', response.token);
      localStorage.setItem('userRole', response.user.role);
      localStorage.setItem('username', response.user.username);

      toast({
        title: "Login Successful",
        description: "Welcome Administrator!"
      });

      // Navigate to admin dashboard
      navigate("/admin/dashboard");

    } catch (error) {
      console.error('Admin login error:', error);
      toast({
        title: "Login Failed",
        description: error instanceof Error ? error.message : "Unable to connect to server. Please try again.",
        variant: "destructive"
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-red-50 to-orange-100 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <Shield className="h-12 w-12 text-red-600 mx-auto mb-4" />
          <h1 className="text-3xl font-bold text-gray-900 mb-2">iBilling Admin</h1>
          <p className="text-gray-600">Administrator Portal</p>
        </div>
        
        <Card className="shadow-xl">
          <CardHeader>
            <CardTitle>Administrator Login</CardTitle>
            <CardDescription>Enter your admin credentials to continue</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="admin-username">Username</Label>
              <Input
                id="admin-username"
                placeholder="Enter admin username"
                value={loginData.username}
                onChange={(e) => setLoginData({ ...loginData, username: e.target.value })}
                disabled={isLoading}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="admin-password">Password</Label>
              <Input
                id="admin-password"
                type="password"
                placeholder="Enter admin password"
                value={loginData.password}
                onChange={(e) => setLoginData({ ...loginData, password: e.target.value })}
                disabled={isLoading}
                onKeyPress={(e) => e.key === 'Enter' && handleLogin()}
              />
            </div>
            
            {/* Demo credentials display */}
            <div className="bg-gray-50 p-3 rounded-lg text-sm">
              <div className="font-semibold mb-2">Demo Admin Credentials:</div>
              <div><strong>Username:</strong> admin</div>
              <div><strong>Password:</strong> admin123</div>
            </div>
            
            <Button 
              onClick={handleLogin}
              className="w-full bg-red-600 hover:bg-red-700"
              disabled={isLoading}
            >
              {isLoading ? "Logging in..." : "Admin Login"}
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default AdminLogin;
