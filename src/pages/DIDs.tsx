
import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import DIDForm from "@/components/DIDForm";

interface DID {
  number: string;
  customer: string;
  country: string;
  rate: string;
  status: string;
  type: string;
  customerId?: string;
  notes?: string;
}

const INITIAL_DIDS: DID[] = [
  { number: "+1-555-0123", customer: "John Doe", country: "USA", rate: "$5.00", status: "Active", type: "Local" },
  { number: "+44-20-7946-0958", customer: "Jane Smith", country: "UK", rate: "$8.00", status: "Active", type: "International" },
  { number: "+1-555-0456", customer: "Unassigned", country: "USA", rate: "$5.00", status: "Available", type: "Local" },
  { number: "+1-800-555-0789", customer: "Bob Johnson", country: "USA", rate: "$12.00", status: "Active", type: "Toll-Free" },
  { number: "+49-30-12345678", customer: "Alice Wilson", country: "Germany", rate: "$10.00", status: "Active", type: "International" }
];

const DIDs = () => {
  const [dids, setDids] = useState<DID[]>(INITIAL_DIDS);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [editingDID, setEditingDID] = useState<DID | null>(null);
  const [searchTerm, setSearchTerm] = useState("");

  const handleDIDCreated = (newDID: DID) => {
    setDids(prev => [...prev, newDID]);
  };

  const handleDIDUpdated = (updatedDID: DID) => {
    setDids(prev => prev.map(did => 
      did.number === updatedDID.number ? updatedDID : did
    ));
    setEditingDID(null);
  };

  const handleEditDID = (did: DID) => {
    setEditingDID(did);
  };

  const handleCloseForm = () => {
    setShowCreateForm(false);
    setEditingDID(null);
  };

  const filteredDids = dids.filter(did =>
    did.number.toLowerCase().includes(searchTerm.toLowerCase()) ||
    did.customer.toLowerCase().includes(searchTerm.toLowerCase()) ||
    did.country.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">DID Management</h1>
        <p className="text-gray-600">Manage Direct Inward Dialing numbers</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>DID Management</CardTitle>
          <CardDescription>Manage Direct Inward Dialing numbers</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <Input 
                placeholder="Search DIDs..." 
                className="max-w-sm" 
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
              <Button 
                className="bg-blue-600 hover:bg-blue-700"
                onClick={() => setShowCreateForm(true)}
              >
                Add New DID
              </Button>
            </div>
            <div className="border rounded-lg">
              <table className="w-full">
                <thead className="border-b bg-gray-50">
                  <tr>
                    <th className="text-left p-4">DID Number</th>
                    <th className="text-left p-4">Customer</th>
                    <th className="text-left p-4">Country</th>
                    <th className="text-left p-4">Monthly Rate</th>
                    <th className="text-left p-4">Type</th>
                    <th className="text-left p-4">Status</th>
                    <th className="text-left p-4">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredDids.map((did, index) => (
                    <tr key={index} className="border-b">
                      <td className="p-4 font-mono">{did.number}</td>
                      <td className="p-4">{did.customer}</td>
                      <td className="p-4">{did.country}</td>
                      <td className="p-4">{did.rate}</td>
                      <td className="p-4">{did.type}</td>
                      <td className="p-4">
                        <span className={`px-2 py-1 rounded-full text-xs ${
                          did.status === "Active" ? "bg-green-100 text-green-800" : 
                          did.status === "Available" ? "bg-yellow-100 text-yellow-800" :
                          "bg-red-100 text-red-800"
                        }`}>
                          {did.status}
                        </span>
                      </td>
                      <td className="p-4">
                        <Button 
                          variant="outline" 
                          size="sm"
                          onClick={() => handleEditDID(did)}
                        >
                          Manage
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </CardContent>
      </Card>

      {(showCreateForm || editingDID) && (
        <DIDForm
          onClose={handleCloseForm}
          onDIDCreated={handleDIDCreated}
          onDIDUpdated={handleDIDUpdated}
          editingDID={editingDID}
        />
      )}
    </div>
  );
};

export default DIDs;
