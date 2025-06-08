
import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useToast } from "@/hooks/use-toast";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { apiClient } from "@/lib/api";

interface Rate {
  id: string;
  destination: string;
  prefix: string;
  rate: string;
  connection: string;
  description: string;
}

const Rates = () => {
  const { toast } = useToast();
  const [rates, setRates] = useState<Rate[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(false);
  const [isEditDialogOpen, setIsEditDialogOpen] = useState(false);
  const [editingRate, setEditingRate] = useState<Rate | null>(null);
  
  // Rate form state
  const [rateForm, setRateForm] = useState({
    destination: "",
    prefix: "",
    rate: "",
    connection: "",
    description: ""
  });

  useEffect(() => {
    fetchRates();
  }, []);

  const fetchRates = async () => {
    try {
      console.log('Fetching rates from database...');
      const data = await apiClient.getRates() as any[];
      console.log('Rates data received:', data);
      
      // Transform the data to match our interface
      const transformedRates = data.map((rate: any) => ({
        id: rate.id || rate.rate_id,
        destination: rate.destination,
        prefix: rate.prefix,
        rate: rate.rate ? `$${rate.rate}` : "$0.00",
        connection: rate.connection_fee ? `$${rate.connection_fee}` : "$0.00",
        description: rate.description || ""
      }));
      
      setRates(transformedRates);
    } catch (error) {
      console.error('Error fetching rates:', error);
      toast({
        title: "Error",
        description: "Failed to load rates from database",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const filteredRates = rates.filter(rate =>
    rate.destination.toLowerCase().includes(searchTerm.toLowerCase()) ||
    rate.prefix.includes(searchTerm) ||
    rate.description.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleCreateRate = () => {
    setRateForm({
      destination: "",
      prefix: "",
      rate: "",
      connection: "",
      description: ""
    });
    setIsCreateDialogOpen(true);
  };

  const handleEditRate = (rate: Rate) => {
    setEditingRate(rate);
    setRateForm({
      destination: rate.destination,
      prefix: rate.prefix,
      rate: rate.rate,
      connection: rate.connection,
      description: rate.description
    });
    setIsEditDialogOpen(true);
  };

  const handleSaveRate = async (isEdit: boolean) => {
    if (!rateForm.destination || !rateForm.prefix || !rateForm.rate || !rateForm.connection) {
      toast({
        title: "Error",
        description: "Please fill in all required fields",
        variant: "destructive",
      });
      return;
    }

    try {
      if (isEdit && editingRate) {
        await apiClient.updateRate({ ...editingRate, ...rateForm });
        toast({
          title: "Rate Updated",
          description: `${rateForm.destination} rate has been successfully updated`,
        });
      } else {
        await apiClient.createRate(rateForm);
        toast({
          title: "Rate Created",
          description: `${rateForm.destination} rate has been successfully created`,
        });
      }

      setIsCreateDialogOpen(false);
      setIsEditDialogOpen(false);
      setEditingRate(null);
      fetchRates(); // Refresh data
    } catch (error) {
      console.error('Error saving rate:', error);
      toast({
        title: "Error",
        description: "Failed to save rate",
        variant: "destructive",
      });
    }
  };

  const handleDeleteRate = async (rateId: string) => {
    try {
      await apiClient.deleteRate(rateId);
      toast({
        title: "Rate Deleted",
        description: "Rate has been successfully deleted",
      });
      fetchRates(); // Refresh data
    } catch (error) {
      console.error('Error deleting rate:', error);
      toast({
        title: "Error",
        description: "Failed to delete rate",
        variant: "destructive",
      });
    }
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Rate Management</h1>
          <p className="text-gray-600">Loading rates from database...</p>
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
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Rate Management</h1>
        <p className="text-gray-600">Configure call rates and pricing</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Rate Management</CardTitle>
          <CardDescription>
            Configure call rates and pricing ({rates.length} rates loaded from database)
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <Input 
                placeholder="Search destinations..." 
                className="max-w-sm" 
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
              <div className="flex space-x-2">
                <Button variant="outline" onClick={fetchRates}>
                  Refresh
                </Button>
                <Button 
                  className="bg-blue-600 hover:bg-blue-700"
                  onClick={handleCreateRate}
                >
                  Add New Rate
                </Button>
              </div>
            </div>
            
            {filteredRates.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                <p>No rates found</p>
                {searchTerm && <p className="text-sm">Try adjusting your search terms</p>}
                {!searchTerm && rates.length === 0 && (
                  <p className="text-sm">Add your first rate to get started</p>
                )}
              </div>
            ) : (
              <div className="border rounded-lg">
                <table className="w-full">
                  <thead className="border-b bg-gray-50">
                    <tr>
                      <th className="text-left p-4">Destination</th>
                      <th className="text-left p-4">Prefix</th>
                      <th className="text-left p-4">Rate per Min</th>
                      <th className="text-left p-4">Connection Fee</th>
                      <th className="text-left p-4">Description</th>
                      <th className="text-left p-4">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredRates.map((rate) => (
                      <tr key={rate.id} className="border-b">
                        <td className="p-4">{rate.destination}</td>
                        <td className="p-4 font-mono">{rate.prefix}</td>
                        <td className="p-4">{rate.rate}</td>
                        <td className="p-4">{rate.connection}</td>
                        <td className="p-4 text-sm text-gray-600">{rate.description}</td>
                        <td className="p-4">
                          <div className="flex space-x-2">
                            <Button 
                              variant="outline" 
                              size="sm"
                              onClick={() => handleEditRate(rate)}
                            >
                              Edit
                            </Button>
                            <Button 
                              variant="outline" 
                              size="sm" 
                              onClick={() => handleDeleteRate(rate.id)}
                              className="text-red-600 hover:text-red-700"
                            >
                              Delete
                            </Button>
                          </div>
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

      {/* Create Rate Dialog */}
      <Dialog open={isCreateDialogOpen} onOpenChange={setIsCreateDialogOpen}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Create New Rate</DialogTitle>
            <DialogDescription>
              Add a new rate configuration. Fill in all the details below.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="space-y-2">
              <Label>Destination *</Label>
              <Input
                value={rateForm.destination}
                onChange={(e) => setRateForm({...rateForm, destination: e.target.value})}
                placeholder="e.g., USA Local, UK Mobile"
              />
            </div>
            <div className="space-y-2">
              <Label>Prefix *</Label>
              <Input
                value={rateForm.prefix}
                onChange={(e) => setRateForm({...rateForm, prefix: e.target.value})}
                placeholder="e.g., 1, 447, 49"
              />
            </div>
            <div className="space-y-2">
              <Label>Rate per Minute *</Label>
              <Input
                value={rateForm.rate}
                onChange={(e) => setRateForm({...rateForm, rate: e.target.value})}
                placeholder="e.g., $0.02"
              />
            </div>
            <div className="space-y-2">
              <Label>Connection Fee *</Label>
              <Input
                value={rateForm.connection}
                onChange={(e) => setRateForm({...rateForm, connection: e.target.value})}
                placeholder="e.g., $0.01"
              />
            </div>
            <div className="space-y-2">
              <Label>Description</Label>
              <Textarea
                value={rateForm.description}
                onChange={(e) => setRateForm({...rateForm, description: e.target.value})}
                placeholder="Description of the rate"
              />
            </div>
          </div>
          <DialogFooter>
            <Button type="submit" onClick={() => handleSaveRate(false)}>
              Create Rate
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Edit Rate Dialog */}
      <Dialog open={isEditDialogOpen} onOpenChange={setIsEditDialogOpen}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Edit Rate</DialogTitle>
            <DialogDescription>
              Make changes to the rate configuration. Click save when you're done.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="space-y-2">
              <Label>Destination *</Label>
              <Input
                value={rateForm.destination}
                onChange={(e) => setRateForm({...rateForm, destination: e.target.value})}
                placeholder="e.g., USA Local, UK Mobile"
              />
            </div>
            <div className="space-y-2">
              <Label>Prefix *</Label>
              <Input
                value={rateForm.prefix}
                onChange={(e) => setRateForm({...rateForm, prefix: e.target.value})}
                placeholder="e.g., 1, 447, 49"
              />
            </div>
            <div className="space-y-2">
              <Label>Rate per Minute *</Label>
              <Input
                value={rateForm.rate}
                onChange={(e) => setRateForm({...rateForm, rate: e.target.value})}
                placeholder="e.g., $0.02"
              />
            </div>
            <div className="space-y-2">
              <Label>Connection Fee *</Label>
              <Input
                value={rateForm.connection}
                onChange={(e) => setRateForm({...rateForm, connection: e.target.value})}
                placeholder="e.g., $0.01"
              />
            </div>
            <div className="space-y-2">
              <Label>Description</Label>
              <Textarea
                value={rateForm.description}
                onChange={(e) => setRateForm({...rateForm, description: e.target.value})}
                placeholder="Description of the rate"
              />
            </div>
          </div>
          <DialogFooter>
            <Button type="submit" onClick={() => handleSaveRate(true)}>
              Save Changes
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default Rates;
