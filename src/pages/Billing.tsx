import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useToast } from "@/hooks/use-toast";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { apiClient } from "@/lib/api";

interface Plan {
  id: string;
  name: string;
  price: string;
  minutes: string;
  features: string[];
}

const Billing = () => {
  const { toast } = useToast();
  const [plans, setPlans] = useState<Plan[]>([]);
  const [loading, setLoading] = useState(true);
  const [isEditDialogOpen, setIsEditDialogOpen] = useState(false);
  const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(false);
  const [editingPlan, setEditingPlan] = useState<Plan | null>(null);
  
  // Credit refill form state
  const [customerId, setCustomerId] = useState("");
  const [refillAmount, setRefillAmount] = useState("");
  
  // Plan form state
  const [planForm, setPlanForm] = useState({
    name: "",
    price: "",
    minutes: "",
    features: ""
  });

  useEffect(() => {
    fetchPlans();
  }, []);

  const fetchPlans = async () => {
    try {
      console.log('Fetching billing plans from database...');
      const data = await apiClient.getBillingPlans() as any[];
      console.log('Billing plans data received:', data);
      
      // Transform the data to match our interface
      const transformedPlans = data.map((plan: any) => ({
        id: plan.id,
        name: plan.name,
        price: plan.price ? `$${plan.price}/month` : "$0/month",
        minutes: plan.minutes || "0 mins",
        features: plan.features ? (Array.isArray(plan.features) ? plan.features : plan.features.split(',')) : []
      }));
      
      setPlans(transformedPlans);
    } catch (error) {
      console.error('Error fetching billing plans:', error);
      toast({
        title: "Error",
        description: "Failed to load billing plans from database",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const handleProcessRefill = async () => {
    if (!customerId || !refillAmount) {
      toast({
        title: "Error",
        description: "Please fill in all required fields",
        variant: "destructive",
      });
      return;
    }

    try {
      await apiClient.processRefill(customerId, parseFloat(refillAmount));
      toast({
        title: "Refill Processed",
        description: `Successfully added $${refillAmount} credit to customer ${customerId}`,
      });
      
      setCustomerId("");
      setRefillAmount("");
    } catch (error) {
      console.error('Error processing refill:', error);
      toast({
        title: "Error",
        description: "Failed to process credit refill",
        variant: "destructive",
      });
    }
  };

  const handleEditPlan = (plan: Plan) => {
    setEditingPlan(plan);
    setPlanForm({
      name: plan.name,
      price: plan.price,
      minutes: plan.minutes,
      features: plan.features.join(", ")
    });
    setIsEditDialogOpen(true);
  };

  const handleCreatePlan = () => {
    setPlanForm({
      name: "",
      price: "",
      minutes: "",
      features: ""
    });
    setIsCreateDialogOpen(true);
  };

  const handleSavePlan = async (isEdit: boolean) => {
    if (!planForm.name || !planForm.price || !planForm.minutes) {
      toast({
        title: "Error",
        description: "Please fill in all required fields",
        variant: "destructive",
      });
      return;
    }

    const features = planForm.features.split(",").map(f => f.trim()).filter(f => f);
    
    try {
      if (isEdit && editingPlan) {
        const updatedPlan = { ...editingPlan, ...planForm, features };
        await apiClient.updateBillingPlan(updatedPlan);
        toast({
          title: "Plan Updated",
          description: `${planForm.name} has been successfully updated`,
        });
      } else {
        const newPlan = {
          id: Date.now().toString(),
          name: planForm.name,
          price: planForm.price,
          minutes: planForm.minutes,
          features
        };
        await apiClient.createBillingPlan(newPlan);
        toast({
          title: "Plan Created",
          description: `${planForm.name} has been successfully created`,
        });
      }

      setIsEditDialogOpen(false);
      setIsCreateDialogOpen(false);
      setEditingPlan(null);
      fetchPlans(); // Refresh from database
    } catch (error) {
      console.error('Error saving plan:', error);
      toast({
        title: "Error",
        description: "Failed to save billing plan",
        variant: "destructive",
      });
    }
  };

  const handleDeletePlan = async (planId: string) => {
    try {
      await apiClient.deleteBillingPlan(planId);
      toast({
        title: "Plan Deleted",
        description: "Plan has been successfully deleted",
      });
      fetchPlans(); // Refresh from database
    } catch (error) {
      console.error('Error deleting plan:', error);
      toast({
        title: "Error",
        description: "Failed to delete billing plan",
        variant: "destructive",
      });
    }
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Billing Management</h1>
          <p className="text-gray-600">Loading billing data from database...</p>
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
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Billing Management</h1>
        <p className="text-gray-600">Manage credit refills, plans, and billing configurations</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Credit Refill</CardTitle>
            <CardDescription>Process customer credit refills</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label>Customer ID</Label>
              <Input 
                placeholder="Enter customer ID" 
                value={customerId}
                onChange={(e) => setCustomerId(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label>Amount ($)</Label>
              <Input 
                placeholder="Enter amount" 
                type="number" 
                value={refillAmount}
                onChange={(e) => setRefillAmount(e.target.value)}
              />
            </div>
            <Button 
              className="w-full bg-green-600 hover:bg-green-700"
              onClick={handleProcessRefill}
            >
              Process Refill
            </Button>
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader>
            <CardTitle>Plan Management</CardTitle>
            <CardDescription>
              Manage billing plans and packages ({plans.length} plans loaded from database)
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <h4 className="font-medium mb-2">Available Plans</h4>
              <div className="space-y-2">
                {plans.map((plan) => (
                  <div key={plan.id} className="flex justify-between items-center p-2 border rounded">
                    <div>
                      <div className="font-medium">{plan.name}</div>
                      <div className="text-sm text-gray-600">{plan.price} • {plan.minutes}</div>
                    </div>
                    <div className="flex space-x-2">
                      <Button variant="outline" size="sm" onClick={() => handleEditPlan(plan)}>
                        Edit
                      </Button>
                      <Button 
                        variant="outline" 
                        size="sm" 
                        onClick={() => handleDeletePlan(plan.id)}
                        className="text-red-600 hover:text-red-700"
                      >
                        Delete
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
              <div className="flex space-x-2">
                <Button className="flex-1" variant="outline" onClick={handleCreatePlan}>
                  Create New Plan
                </Button>
                <Button variant="outline" onClick={fetchPlans}>
                  Refresh
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Edit Plan Dialog */}
      <Dialog open={isEditDialogOpen} onOpenChange={setIsEditDialogOpen}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Edit Plan</DialogTitle>
            <DialogDescription>
              Make changes to the billing plan. Click save when you're done.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="space-y-2">
              <Label>Plan Name</Label>
              <Input
                value={planForm.name}
                onChange={(e) => setPlanForm({...planForm, name: e.target.value})}
                placeholder="Enter plan name"
              />
            </div>
            <div className="space-y-2">
              <Label>Price</Label>
              <Input
                value={planForm.price}
                onChange={(e) => setPlanForm({...planForm, price: e.target.value})}
                placeholder="e.g., $10/month"
              />
            </div>
            <div className="space-y-2">
              <Label>Minutes</Label>
              <Input
                value={planForm.minutes}
                onChange={(e) => setPlanForm({...planForm, minutes: e.target.value})}
                placeholder="e.g., 500 mins"
              />
            </div>
            <div className="space-y-2">
              <Label>Features (comma-separated)</Label>
              <Textarea
                value={planForm.features}
                onChange={(e) => setPlanForm({...planForm, features: e.target.value})}
                placeholder="Local calls, Basic support, etc."
              />
            </div>
          </div>
          <DialogFooter>
            <Button type="submit" onClick={() => handleSavePlan(true)}>
              Save Changes
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Create Plan Dialog */}
      <Dialog open={isCreateDialogOpen} onOpenChange={setIsCreateDialogOpen}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Create New Plan</DialogTitle>
            <DialogDescription>
              Create a new billing plan. Fill in all the details below.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="space-y-2">
              <Label>Plan Name</Label>
              <Input
                value={planForm.name}
                onChange={(e) => setPlanForm({...planForm, name: e.target.value})}
                placeholder="Enter plan name"
              />
            </div>
            <div className="space-y-2">
              <Label>Price</Label>
              <Input
                value={planForm.price}
                onChange={(e) => setPlanForm({...planForm, price: e.target.value})}
                placeholder="e.g., $10/month"
              />
            </div>
            <div className="space-y-2">
              <Label>Minutes</Label>
              <Input
                value={planForm.minutes}
                onChange={(e) => setPlanForm({...planForm, minutes: e.target.value})}
                placeholder="e.g., 500 mins"
              />
            </div>
            <div className="space-y-2">
              <Label>Features (comma-separated)</Label>
              <Textarea
                value={planForm.features}
                onChange={(e) => setPlanForm({...planForm, features: e.target.value})}
                placeholder="Local calls, Basic support, etc."
              />
            </div>
          </div>
          <DialogFooter>
            <Button type="submit" onClick={() => handleSavePlan(false)}>
              Create Plan
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Card className="mt-6">
        <CardHeader>
          <CardTitle>Billing Configuration</CardTitle>
          <CardDescription>Configure billing settings and payment options</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-4">
              <h4 className="font-medium">Prepaid Settings</h4>
              <div className="space-y-2">
                <Label>Minimum Balance Warning</Label>
                <Input placeholder="$5.00" />
              </div>
              <div className="space-y-2">
                <Label>Auto-suspend Threshold</Label>
                <Input placeholder="$0.00" />
              </div>
            </div>
            <div className="space-y-4">
              <h4 className="font-medium">Postpaid Settings</h4>
              <div className="space-y-2">
                <Label>Credit Limit</Label>
                <Input placeholder="$100.00" />
              </div>
              <div className="space-y-2">
                <Label>Billing Cycle</Label>
                <Input placeholder="Monthly" />
              </div>
            </div>
          </div>
          <Button className="mt-6 bg-blue-600 hover:bg-blue-700">Save Configuration</Button>
        </CardContent>
      </Card>
    </div>
  );
};

export default Billing;
