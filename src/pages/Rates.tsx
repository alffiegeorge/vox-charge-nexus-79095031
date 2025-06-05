
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

const DUMMY_RATES = [
  { destination: "USA Local", prefix: "1", rate: "$0.02", connection: "$0.01", description: "US Local calls" },
  { destination: "UK Mobile", prefix: "447", rate: "$0.15", connection: "$0.05", description: "UK Mobile numbers" },
  { destination: "Canada", prefix: "1", rate: "$0.03", connection: "$0.01", description: "Canada calls" },
  { destination: "Germany", prefix: "49", rate: "$0.08", connection: "$0.03", description: "Germany calls" },
  { destination: "Australia Mobile", prefix: "614", rate: "$0.25", connection: "$0.08", description: "Australia Mobile" }
];

const Rates = () => {
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
              <Input placeholder="Search destinations..." className="max-w-sm" />
              <Button className="bg-blue-600 hover:bg-blue-700">Add New Rate</Button>
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
                  {DUMMY_RATES.map((rate, index) => (
                    <tr key={index} className="border-b">
                      <td className="p-4">{rate.destination}</td>
                      <td className="p-4 font-mono">{rate.prefix}</td>
                      <td className="p-4">{rate.rate}</td>
                      <td className="p-4">{rate.connection}</td>
                      <td className="p-4 text-sm text-gray-600">{rate.description}</td>
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

export default Rates;
