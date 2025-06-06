import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useToast } from "@/hooks/use-toast";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";

interface Plan {
  id: string;
  name: string;
  price: string;
  minutes: string;
  features: string[];
}

const DUMMY_PLANS: Plan[] = [
  { id: "1", name: "Basic Plan", price: "$10/month", minutes: "500 mins", features: ["Local calls", "Basic support"] },
  { id: "2", name: "Standard Plan", price: "$25/month", minutes: "1500 mins", features: ["Local + International", "Email support", "Call forwarding"] },
  { id: "3", name: "Premium Plan", price: "$50/month", minutes: "Unlimited", features: ["All destinations", "24/7 support", "Advanced features", "Priority routing"] }
];

const Billing = () => {
  const { toast } = useToast();
  const [plans, setPlans] = useState<Plan[]>(DUMMY_PLANS);
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

  const handleProcessRefill = () => {
    if (!customerId || !refillAmount) {
      toast({
        title: "Error",
        description: "Please fill in all required fields",
        variant: "destructive",
      });
      return;
    }

    // Simulate processing
    toast({
      title: "Refill Processed",
      description: `Successfully added $${refillAmount} credit to customer ${customerId}`,
    });
    
    setCustomerId("");
    setRefillAmount("");
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

  const handleSavePlan = (isEdit: boolean) => {
    if (!planForm.name || !planForm.price || !planForm.minutes) {
      toast({
        title: "Error",
        description: "Please fill in all required fields",
        variant: "destructive",
      });
      return;
    }

    const features = planForm.features.split(",").map(f => f.trim()).filter(f => f);
    
    if (isEdit && editingPlan) {
      const updatedPlans = plans.map(plan => 
        plan.id === editingPlan.id 
          ? { ...plan, ...planForm, features }
          : plan
      );
      setPlans(updatedPlans);
      toast({
        title: "Plan Updated",
        description: `${planForm.name} has been successfully updated`,
      });
    } else {
      const newPlan: Plan = {
        id: Date.now().toString(),
        name: planForm.name,
        price: planForm.price,
        minutes: planForm.minutes,
        features
      };
      setPlans([...plans, newPlan]);
      toast({
        title: "Plan Created",
        description: `${planForm.name} has been successfully created`,
      });
    }

    setIsEditDialogOpen(false);
    setIsCreateDialogOpen(false);
    setEditingPlan(null);
  };

  const handleDeletePlan = (planId: string) => {
    const updatedPlans = plans.filter(plan => plan.id !== planId);
    setPlans(updatedPlans);
    toast({
      title: "Plan Deleted",
      description: "Plan has been successfully deleted",
    });
  };

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
            <CardDescription>Manage billing plans and packages</CardDescription>
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
              <Button className="w-full mt-4" variant="outline" onClick={handleCreatePlan}>
                Create New Plan
              </Button>
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
