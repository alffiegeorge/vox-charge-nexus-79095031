
import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useToast } from "@/hooks/use-toast";
import { apiClient } from "@/lib/api";
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

const DIDs = () => {
  const { toast } = useToast();
  const [dids, setDids] = useState<DID[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [editingDID, setEditingDID] = useState<DID | null>(null);
  const [searchTerm, setSearchTerm] = useState("");

  useEffect(() => {
    fetchDIDs();
  }, []);

  const fetchDIDs = async () => {
    try {
      console.log('Fetching DIDs from database...');
      const data = await apiClient.getDIDs() as any[];
      console.log('DIDs data received:', data);
      
      // Transform the data to match our interface
      const transformedDIDs = data.map((did: any) => ({
        number: did.number || did.did_number,
        customer: did.customer_name || did.customer || "Unassigned",
        country: did.country,
        rate: did.rate ? `$${did.rate}` : "$0.00",
        status: did.status,
        type: did.type || "Local",
        customerId: did.customer_id,
        notes: did.notes
      }));
      
      setDids(transformedDIDs);
    } catch (error) {
      console.error('Error fetching DIDs:', error);
      toast({
        title: "Error",
        description: "Failed to load DIDs from database",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const handleDIDCreated = async (newDID: DID) => {
    try {
      await apiClient.createDID(newDID);
      setDids(prev => [...prev, newDID]);
      toast({
        title: "DID Created",
        description: `DID ${newDID.number} has been created successfully`,
      });
      fetchDIDs(); // Refresh from database
    } catch (error) {
      console.error('Error creating DID:', error);
      toast({
        title: "Error",
        description: "Failed to create DID",
        variant: "destructive",
      });
    }
  };

  const handleDIDUpdated = async (updatedDID: DID) => {
    try {
      await apiClient.updateDID(updatedDID);
      setDids(prev => prev.map(did => 
        did.number === updatedDID.number ? updatedDID : did
      ));
      setEditingDID(null);
      toast({
        title: "DID Updated",
        description: `DID ${updatedDID.number} has been updated successfully`,
      });
      fetchDIDs(); // Refresh from database
    } catch (error) {
      console.error('Error updating DID:', error);
      toast({
        title: "Error",
        description: "Failed to update DID",
        variant: "destructive",
      });
    }
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

  if (loading) {
    return (
      <div className="p-6">
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">DID Management</h1>
          <p className="text-gray-600">Loading DIDs from database...</p>
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
        <h1 className="text-3xl font-bold text-gray-900 mb-2">DID Management</h1>
        <p className="text-gray-600">Manage Direct Inward Dialing numbers</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>DID Management</CardTitle>
          <CardDescription>
            Manage Direct Inward Dialing numbers ({dids.length} DIDs loaded from database)
          </CardDescription>
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
              <div className="flex space-x-2">
                <Button 
                  variant="outline"
                  onClick={fetchDIDs}
                >
                  Refresh
                </Button>
                <Button 
                  className="bg-blue-600 hover:bg-blue-700"
                  onClick={() => setShowCreateForm(true)}
                >
                  Add New DID
                </Button>
              </div>
            </div>
            
            {filteredDids.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                <p>No DIDs found</p>
                {searchTerm && <p className="text-sm">Try adjusting your search terms</p>}
                {!searchTerm && dids.length === 0 && (
                  <p className="text-sm">Add your first DID to get started</p>
                )}
              </div>
            ) : (
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
            )}
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
