
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { useState, useEffect } from "react";
import { apiClient } from "@/lib/api";

interface CallRecord {
  date: string;
  time: string;
  number: string;
  destination: string;
  duration: string;
  cost: string;
  status: string;
}

const CustomerCallHistory = () => {
  const { toast } = useToast();
  const [searchTerm, setSearchTerm] = useState("");
  const [filterDate, setFilterDate] = useState("");
  const [callHistory, setCallHistory] = useState<CallRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [totalCalls, setTotalCalls] = useState(0);
  const [totalMinutes, setTotalMinutes] = useState(0);
  const [totalCost, setTotalCost] = useState(0);

  useEffect(() => {
    fetchCallHistory();
  }, []);

  const fetchCallHistory = async () => {
    try {
      console.log('Fetching call history from database...');
      const data = await apiClient.getCDR() as any;
      console.log('Call history data received:', data);
      
      const records = data.records || [];
      
      // Transform the data to match our interface
      const transformedCalls = records.map((record: any) => ({
        date: record.calldate ? record.calldate.split(' ')[0] : 'N/A',
        time: record.calldate ? record.calldate.split(' ')[1] || 'N/A' : 'N/A',
        number: record.dst || record.destination || 'Unknown',
        destination: record.dcontext || record.destination || 'Unknown',
        duration: record.billsec ? `${Math.floor(record.billsec / 60)}:${(record.billsec % 60).toString().padStart(2, '0')}` : '0:00',
        cost: record.billsec ? `$${(record.billsec * 0.01).toFixed(2)}` : '$0.00',
        status: record.disposition || 'Unknown'
      }));
      
      setCallHistory(transformedCalls);
      
      // Calculate statistics
      setTotalCalls(records.length);
      const totalSeconds = records.reduce((sum: number, record: any) => sum + (record.billsec || 0), 0);
      setTotalMinutes(Math.floor(totalSeconds / 60));
      setTotalCost(Number((totalSeconds * 0.01).toFixed(2)));
      
    } catch (error) {
      console.error('Error fetching call history:', error);
      toast({
        title: "Error",
        description: "Failed to load call history from database",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = (value: string) => {
    setSearchTerm(value);
    filterCalls(value, filterDate);
  };

  const handleDateFilter = (date: string) => {
    setFilterDate(date);
    filterCalls(searchTerm, date);
  };

  const filterCalls = (search: string, date: string) => {
    let filtered = callHistory;

    if (search) {
      filtered = filtered.filter(call => 
        call.number.toLowerCase().includes(search.toLowerCase()) ||
        call.destination.toLowerCase().includes(search.toLowerCase())
      );
    }

    if (date) {
      filtered = filtered.filter(call => call.date === date);
    }

    toast({
      title: "Filters Applied",
      description: `Found ${filtered.length} matching calls`,
    });
  };

  const filteredCalls = callHistory.filter(call => {
    const matchesSearch = !searchTerm || 
      call.number.toLowerCase().includes(searchTerm.toLowerCase()) ||
      call.destination.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesDate = !filterDate || call.date === filterDate;
    
    return matchesSearch && matchesDate;
  });

  const handleExportCalls = () => {
    toast({
      title: "Export Started",
      description: "Your call history is being exported to CSV...",
    });

    // Simulate export process
    setTimeout(() => {
      toast({
        title: "Export Complete",
        description: "Call history has been downloaded successfully",
      });
    }, 2000);
  };

  const handleCallDetails = (callNumber: string) => {
    toast({
      title: "Call Details",
      description: `Loading detailed information for ${callNumber}`,
    });
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Call History</h1>
          <p className="text-gray-600">Loading call history from database...</p>
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
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Call History</h1>
        <p className="text-gray-600">View your call history and details</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Call Records</CardTitle>
          <CardDescription>
            Your complete call history ({callHistory.length} calls loaded from database)
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <Input 
                placeholder="Search calls..." 
                className="max-w-sm" 
                value={searchTerm}
                onChange={(e) => handleSearch(e.target.value)}
              />
              <div className="flex space-x-2">
                <Input 
                  type="date" 
                  className="max-w-40" 
                  value={filterDate}
                  onChange={(e) => handleDateFilter(e.target.value)}
                />
                <Button variant="outline" onClick={fetchCallHistory}>
                  Refresh
                </Button>
                <Button 
                  variant="outline"
                  onClick={handleExportCalls}
                >
                  Export
                </Button>
              </div>
            </div>
            
            {filteredCalls.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                <p>No call records found</p>
                {searchTerm || filterDate ? <p className="text-sm">Try adjusting your search or date filter</p> : <p className="text-sm">No calls have been made yet</p>}
              </div>
            ) : (
              <div className="border rounded-lg">
                <table className="w-full">
                  <thead className="border-b bg-gray-50">
                    <tr>
                      <th className="text-left p-4">Date</th>
                      <th className="text-left p-4">Time</th>
                      <th className="text-left p-4">Number</th>
                      <th className="text-left p-4">Destination</th>
                      <th className="text-left p-4">Duration</th>
                      <th className="text-left p-4">Cost</th>
                      <th className="text-left p-4">Status</th>
                      <th className="text-left p-4">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredCalls.map((call, index) => (
                      <tr key={index} className="border-b">
                        <td className="p-4">{call.date}</td>
                        <td className="p-4">{call.time}</td>
                        <td className="p-4 font-mono">{call.number}</td>
                        <td className="p-4">{call.destination}</td>
                        <td className="p-4">{call.duration}</td>
                        <td className="p-4 font-semibold">{call.cost}</td>
                        <td className="p-4">
                          <span className={`px-2 py-1 rounded-full text-xs ${
                            call.status === "ANSWERED" ? "bg-green-100 text-green-800" : "bg-red-100 text-red-800"
                          }`}>
                            {call.status}
                          </span>
                        </td>
                        <td className="p-4">
                          <Button 
                            variant="ghost" 
                            size="sm"
                            onClick={() => handleCallDetails(call.number)}
                          >
                            Details
                          </Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </CardContent>
      </Card>

      <div className="mt-6 grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Total Calls</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{totalCalls} calls</div>
            <p className="text-sm text-gray-600">{totalMinutes} minutes total</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Total Cost</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">${totalCost.toFixed(2)}</div>
            <p className="text-sm text-gray-600">Total charges</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Success Rate</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-blue-600">
              {totalCalls > 0 ? ((callHistory.filter(call => call.status === 'ANSWERED').length / totalCalls) * 100).toFixed(1) : 0}%
            </div>
            <p className="text-sm text-gray-600">Call completion rate</p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default CustomerCallHistory;
