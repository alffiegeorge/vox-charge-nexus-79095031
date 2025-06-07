
import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Phone } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { useNavigate } from "react-router-dom";
import { apiClient } from "@/lib/api";

const Index = () => {
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
      console.log('Attempting login with:', { username: loginData.username });
      
      const response = await apiClient.login({
        username: loginData.username,
        password: loginData.password
      });

      console.log('Login response:', response);

      // Store authentication token
      localStorage.setItem('authToken', response.token);
      localStorage.setItem('userRole', response.user.role);
      localStorage.setItem('username', response.user.username);

      toast({
        title: "Login Successful",
        description: `Welcome ${response.user.role === "admin" ? "Administrator" : "Customer"}!`
      });

      // Navigate to appropriate dashboard
      if (response.user.role === "admin") {
        navigate("/admin");
      } else {
        navigate("/customer");
      }

    } catch (error) {
      console.error('Login error:', error);
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
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <Phone className="h-12 w-12 text-blue-600 mx-auto mb-4" />
          <h1 className="text-3xl font-bold text-gray-900 mb-2">iBilling</h1>
          <p className="text-gray-600">Professional Voice Billing System</p>
        </div>
        
        <Card className="shadow-xl">
          <CardHeader>
            <CardTitle>Login to Your Account</CardTitle>
            <CardDescription>Enter your credentials to continue</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="username">Username</Label>
              <Input
                id="username"
                placeholder="Enter your username"
                value={loginData.username}
                onChange={(e) => setLoginData({ ...loginData, username: e.target.value })}
                disabled={isLoading}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password">Password</Label>
              <Input
                id="password"
                type="password"
                placeholder="Enter your password"
                value={loginData.password}
                onChange={(e) => setLoginData({ ...loginData, password: e.target.value })}
                disabled={isLoading}
                onKeyPress={(e) => e.key === 'Enter' && handleLogin()}
              />
            </div>
            
            {/* Demo credentials display */}
            <div className="bg-gray-50 p-3 rounded-lg text-sm">
              <div className="font-semibold mb-2">Demo Credentials:</div>
              <div className="space-y-1">
                <div><strong>Admin:</strong> admin / admin123</div>
                <div><strong>Customer:</strong> customer / customer123</div>
              </div>
            </div>
            
            <Button 
              onClick={handleLogin}
              className="w-full bg-blue-600 hover:bg-blue-700"
              disabled={isLoading}
            >
              {isLoading ? "Logging in..." : "Login"}
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default Index;
