
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useToast } from "@/hooks/use-toast";
import { useState } from "react";

const DUMMY_BILLING_HISTORY = [
  { date: "2024-01-01", description: "Credit Refill", amount: "+$50.00", balance: "$125.50", type: "Credit" },
  { date: "2024-01-02", description: "Call Charges", amount: "-$2.45", balance: "$123.05", type: "Debit" },
  { date: "2024-01-03", description: "DID Monthly Fee", amount: "-$5.00", balance: "$118.05", type: "Debit" },
  { date: "2024-01-04", description: "Call Charges", amount: "-$1.23", balance: "$116.82", type: "Debit" },
  { date: "2024-01-05", description: "Call Charges", amount: "-$3.67", balance: "$113.15", type: "Debit" }
];

const CustomerBilling = () => {
  const { toast } = useToast();
  const [creditAmount, setCreditAmount] = useState("");
  const [paymentMethod, setPaymentMethod] = useState("Credit Card");
  const [searchTerm, setSearchTerm] = useState("");
  const [filteredTransactions, setFilteredTransactions] = useState(DUMMY_BILLING_HISTORY);
  const [currentBalance, setCurrentBalance] = useState(125.50);

  const handleAddCredit = () => {
    if (!creditAmount || parseFloat(creditAmount) <= 0) {
      toast({
        title: "Invalid Amount",
        description: "Please enter a valid credit amount",
        variant: "destructive",
      });
      return;
    }

    toast({
      title: "Processing Payment",
      description: `Adding $${creditAmount} to your account via ${paymentMethod}...`,
    });

    // Simulate payment processing
    setTimeout(() => {
      const newBalance = currentBalance + parseFloat(creditAmount);
      setCurrentBalance(newBalance);
      
      toast({
        title: "Payment Successful",
        description: `$${creditAmount} has been added to your account. New balance: $${newBalance.toFixed(2)}`,
      });

      setCreditAmount("");
    }, 2000);
  };

  const handleUpdateSettings = () => {
    toast({
      title: "Settings Updated",
      description: "Your account settings have been successfully updated",
    });
  };

  const handleSearchTransactions = (value: string) => {
    setSearchTerm(value);
    
    if (!value.trim()) {
      setFilteredTransactions(DUMMY_BILLING_HISTORY);
    } else {
      const filtered = DUMMY_BILLING_HISTORY.filter(transaction =>
        transaction.description.toLowerCase().includes(value.toLowerCase()) ||
        transaction.amount.toLowerCase().includes(value.toLowerCase())
      );
      setFilteredTransactions(filtered);
    }

    toast({
      title: "Search Applied",
      description: `Found ${value ? filteredTransactions.length : DUMMY_BILLING_HISTORY.length} transactions`,
    });
  };

  const handleExportTransactions = () => {
    toast({
      title: "Export Started",
      description: "Your billing history is being exported to CSV...",
    });

    // Simulate export process
    setTimeout(() => {
      toast({
        title: "Export Complete",
        description: "Billing history has been downloaded successfully",
      });
    }, 2000);
  };

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Billing & Payments</h1>
        <p className="text-gray-600">Manage your account balance and view billing history</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle>Current Balance</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-600">${currentBalance.toFixed(2)}</div>
            <p className="text-sm text-gray-600 mt-2">Prepaid Account</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>This Month Usage</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">$12.25</div>
            <p className="text-sm text-gray-600 mt-2">245 minutes used</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Next Bill Date</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">Jan 31</div>
            <p className="text-sm text-gray-600 mt-2">DID monthly fees</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Add Credit</CardTitle>
            <CardDescription>Top up your account balance</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label>Amount</Label>
              <Input 
                placeholder="Enter amount" 
                type="number"
                value={creditAmount}
                onChange={(e) => setCreditAmount(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label>Payment Method</Label>
              <select 
                className="w-full border rounded-md p-2"
                value={paymentMethod}
                onChange={(e) => setPaymentMethod(e.target.value)}
              >
                <option>Credit Card</option>
                <option>PayPal</option>
                <option>Bank Transfer</option>
              </select>
            </div>
            <Button 
              className="w-full bg-green-600 hover:bg-green-700"
              onClick={handleAddCredit}
            >
              Add Credit
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Account Information</CardTitle>
            <CardDescription>Your billing details</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex justify-between">
              <span className="text-gray-600">Account Type:</span>
              <span className="font-medium">Prepaid</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Customer ID:</span>
              <span className="font-medium">C001</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Low Balance Alert:</span>
              <span className="font-medium">$10.00</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Auto-refill:</span>
              <span className="text-red-600">Disabled</span>
            </div>
            <Button 
              variant="outline" 
              className="w-full"
              onClick={handleUpdateSettings}
            >
              Update Settings
            </Button>
          </CardContent>
        </Card>
      </div>

      <Card className="mt-6">
        <CardHeader>
          <CardTitle>Billing History</CardTitle>
          <CardDescription>Recent account transactions</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <Input 
                placeholder="Search transactions..." 
                className="max-w-sm"
                value={searchTerm}
                onChange={(e) => handleSearchTransactions(e.target.value)}
              />
              <Button 
                variant="outline"
                onClick={handleExportTransactions}
              >
                Export
              </Button>
            </div>
            <div className="border rounded-lg">
              <table className="w-full">
                <thead className="border-b bg-gray-50">
                  <tr>
                    <th className="text-left p-4">Date</th>
                    <th className="text-left p-4">Description</th>
                    <th className="text-left p-4">Amount</th>
                    <th className="text-left p-4">Balance</th>
                    <th className="text-left p-4">Type</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredTransactions.map((transaction, index) => (
                    <tr key={index} className="border-b">
                      <td className="p-4">{transaction.date}</td>
                      <td className="p-4">{transaction.description}</td>
                      <td className={`p-4 font-semibold ${
                        transaction.type === "Credit" ? "text-green-600" : "text-red-600"
                      }`}>
                        {transaction.amount}
                      </td>
                      <td className="p-4">{transaction.balance}</td>
                      <td className="p-4">
                        <span className={`px-2 py-1 rounded-full text-xs ${
                          transaction.type === "Credit" ? "bg-green-100 text-green-800" : "bg-red-100 text-red-800"
                        }`}>
                          {transaction.type}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};

export default CustomerBilling;
