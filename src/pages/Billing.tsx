
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

const DUMMY_PLANS = [
  { name: "Basic Plan", price: "$10/month", minutes: "500 mins", features: ["Local calls", "Basic support"] },
  { name: "Standard Plan", price: "$25/month", minutes: "1500 mins", features: ["Local + International", "Email support", "Call forwarding"] },
  { name: "Premium Plan", price: "$50/month", minutes: "Unlimited", features: ["All destinations", "24/7 support", "Advanced features", "Priority routing"] }
];

const Billing = () => {
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
              <Input placeholder="Enter customer ID" />
            </div>
            <div className="space-y-2">
              <Label>Amount</Label>
              <Input placeholder="Enter amount" type="number" />
            </div>
            <Button className="w-full bg-green-600 hover:bg-green-700">Process Refill</Button>
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
                {DUMMY_PLANS.map((plan, index) => (
                  <div key={index} className="flex justify-between items-center p-2 border rounded">
                    <div>
                      <div className="font-medium">{plan.name}</div>
                      <div className="text-sm text-gray-600">{plan.price} • {plan.minutes}</div>
                    </div>
                    <Button variant="outline" size="sm">Edit</Button>
                  </div>
                ))}
              </div>
              <Button className="w-full mt-4" variant="outline">Create New Plan</Button>
            </div>
          </CardContent>
        </Card>
      </div>

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
