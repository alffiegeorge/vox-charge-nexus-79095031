
import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Phone, Users, CreditCard, Settings } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { useNavigate } from "react-router-dom";

// Dummy login credentials
const DUMMY_CREDENTIALS = {
  admin: { username: "admin", password: "admin123" },
  customer: { username: "customer", password: "customer123" }
};

const Index = () => {
  const [loginData, setLoginData] = useState({ username: "", password: "" });
  const { toast } = useToast();
  const navigate = useNavigate();

  const handleLogin = (type: "admin" | "customer") => {
    const credentials = DUMMY_CREDENTIALS[type];
    
    if (loginData.username !== credentials.username || loginData.password !== credentials.password) {
      toast({
        title: "Login Failed",
        description: `Invalid credentials. Use ${credentials.username}/${credentials.password}`,
        variant: "destructive"
      });
      return;
    }
    
    toast({
      title: "Login Successful",
      description: `Welcome ${type === "admin" ? "Administrator" : "Customer"}!`
    });

    // Navigate to appropriate dashboard
    if (type === "admin") {
      navigate("/admin");
    } else {
      navigate("/customer");
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <Phone className="h-12 w-12 text-blue-600 mx-auto mb-4" />
          <h1 className="text-3xl font-bold text-gray-900 mb-2">VoiceFlow Billing</h1>
          <p className="text-gray-600">Professional Voice Billing System</p>
        </div>
        
        <Card className="shadow-xl">
          <CardHeader>
            <CardTitle>Login to Your Account</CardTitle>
            <CardDescription>Choose your login type to continue</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="username">Username</Label>
              <Input
                id="username"
                placeholder="Enter your username"
                value={loginData.username}
                onChange={(e) => setLoginData({ ...loginData, username: e.target.value })}
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
              />
            </div>
            
            {/* Dummy credentials display */}
            <div className="bg-gray-50 p-3 rounded-lg text-sm">
              <div className="font-semibold mb-2">Demo Credentials:</div>
              <div className="space-y-1">
                <div><strong>Admin:</strong> admin / admin123</div>
                <div><strong>Customer:</strong> customer / customer123</div>
              </div>
            </div>
            
            <div className="grid grid-cols-2 gap-4 pt-4">
              <Button 
                onClick={() => handleLogin("admin")}
                className="bg-blue-600 hover:bg-blue-700"
              >
                <Settings className="h-4 w-4 mr-2" />
                Admin Login
              </Button>
              <Button 
                onClick={() => handleLogin("customer")}
                variant="outline"
                className="border-blue-600 text-blue-600 hover:bg-blue-50"
              >
                <Users className="h-4 w-4 mr-2" />
                Customer Login
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default Index;
