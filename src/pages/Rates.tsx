
import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useToast } from "@/hooks/use-toast";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";

interface Rate {
  id: string;
  destination: string;
  prefix: string;
  rate: string;
  connection: string;
  description: string;
}

const DUMMY_RATES: Rate[] = [
  { id: "1", destination: "USA Local", prefix: "1", rate: "$0.02", connection: "$0.01", description: "US Local calls" },
  { id: "2", destination: "UK Mobile", prefix: "447", rate: "$0.15", connection: "$0.05", description: "UK Mobile numbers" },
  { id: "3", destination: "Canada", prefix: "1", rate: "$0.03", connection: "$0.01", description: "Canada calls" },
  { id: "4", destination: "Germany", prefix: "49", rate: "$0.08", connection: "$0.03", description: "Germany calls" },
  { id: "5", destination: "Australia Mobile", prefix: "614", rate: "$0.25", connection: "$0.08", description: "Australia Mobile" }
];

const Rates = () => {
  const { toast } = useToast();
  const [rates, setRates] = useState<Rate[]>(DUMMY_RATES);
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

  const handleSaveRate = (isEdit: boolean) => {
    if (!rateForm.destination || !rateForm.prefix || !rateForm.rate || !rateForm.connection) {
      toast({
        title: "Error",
        description: "Please fill in all required fields",
        variant: "destructive",
      });
      return;
    }

    if (isEdit && editingRate) {
      const updatedRates = rates.map(rate => 
        rate.id === editingRate.id 
          ? { ...rate, ...rateForm }
          : rate
      );
      setRates(updatedRates);
      toast({
        title: "Rate Updated",
        description: `${rateForm.destination} rate has been successfully updated`,
      });
    } else {
      const newRate: Rate = {
        id: Date.now().toString(),
        destination: rateForm.destination,
        prefix: rateForm.prefix,
        rate: rateForm.rate,
        connection: rateForm.connection,
        description: rateForm.description
      };
      setRates([...rates, newRate]);
      toast({
        title: "Rate Created",
        description: `${rateForm.destination} rate has been successfully created`,
      });
    }

    setIsCreateDialogOpen(false);
    setIsEditDialogOpen(false);
    setEditingRate(null);
  };

  const handleDeleteRate = (rateId: string) => {
    const updatedRates = rates.filter(rate => rate.id !== rateId);
    setRates(updatedRates);
    toast({
      title: "Rate Deleted",
      description: "Rate has been successfully deleted",
    });
  };

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Rate Management</h1>
        <p className="text-gray-600">Configure call rates and pricing</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Rate Management</CardTitle>
          <CardDescription>Configure call rates and pricing</CardDescription>
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
              <Button 
                className="bg-blue-600 hover:bg-blue-700"
                onClick={handleCreateRate}
              >
                Add New Rate
              </Button>
            </div>
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
