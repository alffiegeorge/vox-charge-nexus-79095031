
import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { useNavigate } from "react-router-dom";
import { apiClient } from "@/lib/api";

interface DashboardStats {
  totalCustomers: number;
  activeCalls: number;
  totalRevenue: number;
  recentCalls: any[];
}

interface Customer {
  id: string;
  name: string;
  email: string;
  phone: string;
  type: string;
  balance: number;
  status: string;
}

const CustomerDashboard = () => {
  const { toast } = useToast();
  const navigate = useNavigate();
  const [dashboardStats, setDashboardStats] = useState<DashboardStats | null>(null);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);

  // Get current user info from localStorage
  const username = localStorage.getItem('username') || 'Guest';
  const userRole = localStorage.getItem('userRole');

  useEffect(() => {
    const fetchData = async () => {
      try {
        console.log('Fetching dashboard data...');
        
        // Fetch dashboard stats
        const stats = await apiClient.getDashboardStats() as DashboardStats;
        console.log('Dashboard stats received:', stats);
        setDashboardStats(stats);

        // Fetch customers data
        const customersData = await apiClient.getCustomers() as Customer[];
        console.log('Customers data received:', customersData);
        setCustomers(customersData);

      } catch (error) {
        console.error('Error fetching dashboard data:', error);
        toast({
          title: "Error",
          description: "Failed to load dashboard data. Using offline mode.",
          variant: "destructive",
        });
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [toast]);

  // Find current user's data if they're a customer
  const currentCustomer = userRole === 'customer' 
    ? customers.find(c => c.name.toLowerCase().includes(username.toLowerCase()))
    : customers[0]; // Default to first customer for demo

  const handleAddCredit = () => {
    toast({
      title: "Add Credit",
      description: "Redirecting to payment gateway...",
    });
    
    // Simulate payment process
    setTimeout(() => {
      toast({
        title: "Credit Added Successfully",
        description: "Your account has been credited with $50.00",
      });
    }, 2000);
  };

  const handleViewAllCalls = () => {
    navigate("/customer/calls");
    toast({
      title: "Navigating",
      description: "Loading call history...",
    });
  };

  const handleViewAllDIDs = () => {
    toast({
      title: "View All DIDs",
      description: "Showing complete list of your phone numbers",
    });
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Customer Dashboard</h1>
          <p className="text-gray-600">Loading your dashboard...</p>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          {[1, 2, 3].map((i) => (
            <Card key={i} className="animate-pulse">
              <CardHeader>
                <div className="h-4 bg-gray-200 rounded w-1/2"></div>
              </CardHeader>
              <CardContent>
                <div className="h-8 bg-gray-200 rounded w-1/3 mb-4"></div>
                <div className="h-10 bg-gray-200 rounded"></div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Customer Dashboard</h1>
        <p className="text-gray-600">Welcome back, {currentCustomer?.name || username}!</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <Card>
          <CardHeader>
            <CardTitle>Account Balance</CardTitle>
          </CardHeader>
          <CardContent>
            <div className={`text-3xl font-bold ${currentCustomer?.balance && currentCustomer.balance >= 0 ? 'text-green-600' : 'text-red-600'}`}>
              ${currentCustomer?.balance?.toFixed(2) || '0.00'}
            </div>
            <Button 
              className="w-full mt-4 bg-blue-600 hover:bg-blue-700"
              onClick={handleAddCredit}
            >
              Add Credit
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Active Calls</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{dashboardStats?.activeCalls || 0}</div>
            <p className="text-sm text-gray-600 mt-2">Live calls now</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Account Status</CardTitle>
          </CardHeader>
          <CardContent>
            <div className={`text-2xl font-bold ${currentCustomer?.status === 'Active' ? 'text-green-600' : 'text-red-600'}`}>
              {currentCustomer?.status || 'Unknown'}
            </div>
            <p className="text-sm text-gray-600 mt-2">Account type: {currentCustomer?.type || 'Unknown'}</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Recent Calls</CardTitle>
            <CardDescription>Your recent call activity</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {dashboardStats?.recentCalls && dashboardStats.recentCalls.length > 0 ? (
                dashboardStats.recentCalls.slice(0, 5).map((call, index) => (
                  <div key={index} className="flex justify-between items-center p-3 border rounded">
                    <div>
                      <div className="font-mono">{call.dst || call.src}</div>
                      <div className="text-sm text-gray-600">
                        {call.disposition} • {new Date(call.calldate).toLocaleString()}
                      </div>
                    </div>
                    <div className="text-right">
                      <div>{Math.floor(call.duration / 60)}:{(call.duration % 60).toString().padStart(2, '0')}</div>
                      <div className="text-sm font-semibold">
                        ${((call.billsec || 0) * 0.01).toFixed(2)}
                      </div>
                    </div>
                  </div>
                ))
              ) : (
                <div className="text-center py-8 text-gray-500">
                  <p>No recent calls found</p>
                  <p className="text-sm">Your call history will appear here</p>
                </div>
              )}
            </div>
            <Button 
              variant="outline" 
              className="w-full mt-4"
              onClick={handleViewAllCalls}
            >
              View All Calls
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Account Information</CardTitle>
            <CardDescription>Your account details</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex justify-between items-center p-3 border rounded">
                <div>
                  <div className="font-semibold">Customer ID</div>
                  <div className="text-sm text-gray-600">{currentCustomer?.id || 'N/A'}</div>
                </div>
              </div>
              <div className="flex justify-between items-center p-3 border rounded">
                <div>
                  <div className="font-semibold">Email</div>
                  <div className="text-sm text-gray-600">{currentCustomer?.email || 'N/A'}</div>
                </div>
              </div>
              <div className="flex justify-between items-center p-3 border rounded">
                <div>
                  <div className="font-semibold">Phone</div>
                  <div className="text-sm text-gray-600">{currentCustomer?.phone || 'N/A'}</div>
                </div>
              </div>
              <div className="flex justify-between items-center p-3 border rounded">
                <div>
                  <div className="font-semibold">Account Type</div>
                  <div className="text-sm text-gray-600">{currentCustomer?.type || 'N/A'}</div>
                </div>
              </div>
            </div>
            <Button 
              variant="outline" 
              className="w-full mt-4"
              onClick={handleViewAllDIDs}
            >
              Manage Settings
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default CustomerDashboard;
