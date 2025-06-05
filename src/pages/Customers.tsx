
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

const DUMMY_CUSTOMERS = [
  { id: "C001", name: "John Doe", email: "john@example.com", type: "Prepaid", balance: "$125.50", status: "Active", phone: "+1-555-0123" },
  { id: "C002", name: "Jane Smith", email: "jane@example.com", type: "Postpaid", balance: "$-45.20", status: "Active", phone: "+1-555-0456" },
  { id: "C003", name: "Bob Johnson", email: "bob@example.com", type: "Prepaid", balance: "$0.00", status: "Suspended", phone: "+1-555-0789" },
  { id: "C004", name: "Alice Wilson", email: "alice@example.com", type: "Prepaid", balance: "$89.75", status: "Active", phone: "+1-555-0321" },
  { id: "C005", name: "Mike Davis", email: "mike@example.com", type: "Postpaid", balance: "$-12.80", status: "Active", phone: "+1-555-0654" }
];

const Customers = () => {
  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Customer Management</h1>
        <p className="text-gray-600">Manage customer accounts and configurations</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Customer Management</CardTitle>
          <CardDescription>Manage customer accounts and configurations</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <Input placeholder="Search customers..." className="max-w-sm" />
              <Button className="bg-blue-600 hover:bg-blue-700">Add New Customer</Button>
            </div>
            <div className="border rounded-lg">
              <table className="w-full">
                <thead className="border-b bg-gray-50">
                  <tr>
                    <th className="text-left p-4">Customer ID</th>
                    <th className="text-left p-4">Name</th>
                    <th className="text-left p-4">Email</th>
                    <th className="text-left p-4">Type</th>
                    <th className="text-left p-4">Balance</th>
                    <th className="text-left p-4">Status</th>
                    <th className="text-left p-4">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {DUMMY_CUSTOMERS.map((customer, index) => (
                    <tr key={index} className="border-b">
                      <td className="p-4">{customer.id}</td>
                      <td className="p-4">{customer.name}</td>
                      <td className="p-4">{customer.email}</td>
                      <td className="p-4">{customer.type}</td>
                      <td className="p-4">{customer.balance}</td>
                      <td className="p-4">
                        <span className={`px-2 py-1 rounded-full text-xs ${
                          customer.status === "Active" ? "bg-green-100 text-green-800" : "bg-red-100 text-red-800"
                        }`}>
                          {customer.status}
                        </span>
                      </td>
                      <td className="p-4">
                        <Button variant="outline" size="sm">Edit</Button>
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

export default Customers;
