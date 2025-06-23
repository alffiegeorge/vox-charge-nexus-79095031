import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
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
  const [error, setError] = useState<string | null>(null);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [editingDID, setEditingDID] = useState<DID | null>(null);
  const [searchTerm, setSearchTerm] = useState("");

  useEffect(() => {
    fetchDIDs();
  }, []);

  const fetchDIDs = async () => {
    try {
      console.log('Fetching DIDs from database...');
      setLoading(true);
      setError(null);

      const data = await apiClient.getDIDs() as any[];
      console.log('DIDs data received:', data);

      if (!Array.isArray(data)) {
        throw new Error(`Expected array but got ${typeof data}`);
      }

      // Transform the data to match our interface with safe property access
      const transformedDIDs = data.map((did: any, index: number) => {
        console.log(`Transforming DID ${index}:`, did);
        return {
          number: did.number || did.did_number || `Unknown-${index}`,
          customer: did.customer_name || did.customer || "Unassigned",
          country: did.country || "Unknown",
          rate: did.rate ? `$${did.rate}` : "$0.00",
          status: did.status || "Unknown",
          type: did.type || "Local",
          customerId: did.customer_id,
          notes: did.notes || ""
        };
      });

      console.log('Transformed DIDs:', transformedDIDs);
      setDids(transformedDIDs);
    } catch (error) {
      console.error('Error fetching DIDs:', error);
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
      setError(`Failed to load DIDs: ${errorMessage}`);
      toast({
        title: "Error",
        description: `Failed to load DIDs from database: ${errorMessage}`,
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
        description: `DID ${newDID.number} has been created successfully${newDID.customerId ? ` and assigned to ${newDID.customer}` : ''}`,
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
        description: `DID ${updatedDID.number} has been updated successfully${updatedDID.customerId ? ` and assigned to ${updatedDID.customer}` : ''}`,
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

  const handleQuickAssign = async (didNumber: string, customerId: string) => {
    try {
      await apiClient.assignDIDToCustomer(didNumber, customerId);
      toast({
        title: "DID Assigned",
        description: `DID ${didNumber} has been assigned successfully`,
      });
      fetchDIDs(); // Refresh from database
    } catch (error) {
      console.error('Error assigning DID:', error);
      toast({
        title: "Error",
        description: "Failed to assign DID",
        variant: "destructive",
      });
    }
  };

  const handleQuickUnassign = async (didNumber: string) => {
    try {
      await apiClient.unassignDID(didNumber);
      toast({
        title: "DID Unassigned",
        description: `DID ${didNumber} has been unassigned successfully`,
      });
      fetchDIDs(); // Refresh from database
    } catch (error) {
      console.error('Error unassigning DID:', error);
      toast({
        title: "Error",
        description: "Failed to unassign DID",
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

  const filteredDids = dids.filter(did => {
    const searchLower = searchTerm.toLowerCase();
    const numberMatch = (did.number || '').toLowerCase().includes(searchLower);
    const customerMatch = (did.customer || '').toLowerCase().includes(searchLower);
    const countryMatch = (did.country || '').toLowerCase().includes(searchLower);

    return numberMatch || customerMatch || countryMatch;
  });

  const getStatusBadge = (status: string, customerId?: string) => {
    if (customerId && status === "Assigned") {
      return <Badge className="bg-green-100 text-green-800">Assigned</Badge>;
    }

    switch (status) {
      case "Available":
        return <Badge variant="secondary">Available</Badge>;
      case "Assigned":
        return <Badge className="bg-blue-100 text-blue-800">Assigned</Badge>;
      case "Reserved":
        return <Badge className="bg-yellow-100 text-yellow-800">Reserved</Badge>;
      case "Suspended":
        return <Badge variant="destructive">Suspended</Badge>;
      default:
        return <Badge variant="outline">{status}</Badge>;
    }
  };

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

  if (error) {
    return (
      <div className="p-6">
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">DID Management</h1>
          <p className="text-red-600">Error loading DIDs</p>
        </div>
        <Card>
          <CardHeader>
            <CardTitle>Error</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-red-600 mb-4">{error}</div>
            <Button onClick={fetchDIDs} variant="outline">
              Try Again
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  const assignedDids = dids.filter(did => did.customerId);
  const availableDids = dids.filter(did => !did.customerId);

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">DID Management</h1>
        <p className="text-gray-600">Manage Direct Inward Dialing numbers and customer assignments</p>
      </div>

      {/* Debug Info */}
      <Card className="mb-4 bg-blue-50">
        <CardContent className="p-4">
          <div className="text-sm">
            <strong>Debug Info:</strong> Loaded {dids.length} DIDs |
            Assigned: {assignedDids.length} |
            Available: {availableDids.length}
          </div>
        </CardContent>
      </Card>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <Card>
          <CardContent className="p-4">
            <div className="text-2xl font-bold text-gray-900">{dids.length}</div>
            <div className="text-sm text-gray-600">Total DIDs</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="text-2xl font-bold text-green-600">{assignedDids.length}</div>
            <div className="text-sm text-gray-600">Assigned DIDs</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="text-2xl font-bold text-blue-600">{availableDids.length}</div>
            <div className="text-sm text-gray-600">Available DIDs</div>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>DID Management</CardTitle>
          <CardDescription>
            Manage Direct Inward Dialing numbers and customer assignments ({dids.length} DIDs loaded from database)
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
                      <th className="text-left p-4">Customer Assignment</th>
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
                        <td className="p-4">
                          <div className="flex flex-col">
                            <span className={did.customerId ? "font-medium" : "text-gray-500"}>
                              {did.customer}
                            </span>
                            {did.customerId && (
                              <span className="text-xs text-gray-500">ID: {did.customerId}</span>
                            )}
                          </div>
                        </td>
                        <td className="p-4">{did.country}</td>
                        <td className="p-4">{did.rate}</td>
                        <td className="p-4">{did.type}</td>
                        <td className="p-4">
                          {getStatusBadge(did.status, did.customerId)}
                        </td>
                        <td className="p-4">
                          <div className="flex space-x-2">
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => handleEditDID(did)}
                            >
                              Edit
                            </Button>
                            {did.customerId ? (
                              <Button
                                variant="outline"
                                size="sm"
                                onClick={() => handleQuickUnassign(did.number)}
                                className="text-red-600 hover:text-red-700"
                              >
                                Unassign
                              </Button>
                            ) : (
                              <Button
                                variant="outline"
                                size="sm"
                                onClick={() => handleEditDID(did)}
                                className="text-green-600 hover:text-green-700"
                              >
                                Assign
                              </Button>
                            )}
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
