
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Progress } from "@/components/ui/progress";

const QUALITY_METRICS = [
  { provider: "Carrier A", asr: 98.5, acd: "2:45", pdd: "1.2s", jitter: "15ms", latency: "120ms", status: "Excellent" },
  { provider: "Carrier B", asr: 96.2, acd: "3:12", pdd: "1.8s", jitter: "22ms", latency: "145ms", status: "Good" },
  { provider: "Carrier C", asr: 94.1, acd: "2:58", pdd: "2.1s", jitter: "28ms", latency: "180ms", status: "Fair" },
  { provider: "Carrier D", asr: 92.8, acd: "2:33", pdd: "2.5s", jitter: "35ms", latency: "220ms", status: "Poor" }
];

const QualityMonitoring = () => {
  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Quality Monitoring</h1>
        <p className="text-gray-600">Monitor call quality, network health, and SIP performance</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6 mb-6">
        <Card>
          <CardHeader>
            <CardTitle>Overall ASR</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-600">96.4%</div>
            <Progress value={96.4} className="mt-2" />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Avg Call Duration</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-blue-600">2:52</div>
            <p className="text-sm text-gray-600">Minutes</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Network Latency</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-orange-600">165ms</div>
            <p className="text-sm text-gray-600">Average</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Active Calls</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-purple-600">1,247</div>
            <p className="text-sm text-gray-600">Live now</p>
          </CardContent>
        </Card>
      </div>

      <Card className="mb-6">
        <CardHeader>
          <CardTitle>Provider Quality Metrics</CardTitle>
          <CardDescription>Real-time quality monitoring by provider</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <Input placeholder="Search providers..." className="max-w-sm" />
              <Button variant="outline">Export Report</Button>
            </div>
            <div className="border rounded-lg">
              <table className="w-full">
                <thead className="border-b bg-gray-50">
                  <tr>
                    <th className="text-left p-4">Provider</th>
                    <th className="text-left p-4">ASR (%)</th>
                    <th className="text-left p-4">ACD</th>
                    <th className="text-left p-4">PDD</th>
                    <th className="text-left p-4">Jitter</th>
                    <th className="text-left p-4">Latency</th>
                    <th className="text-left p-4">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {QUALITY_METRICS.map((metric, index) => (
                    <tr key={index} className="border-b">
                      <td className="p-4">{metric.provider}</td>
                      <td className="p-4">
                        <div className="flex items-center space-x-2">
                          <span>{metric.asr}%</span>
                          <Progress value={metric.asr} className="w-16" />
                        </div>
                      </td>
                      <td className="p-4">{metric.acd}</td>
                      <td className="p-4">{metric.pdd}</td>
                      <td className="p-4">{metric.jitter}</td>
                      <td className="p-4">{metric.latency}</td>
                      <td className="p-4">
                        <span className={`px-2 py-1 rounded-full text-xs ${
                          metric.status === "Excellent" ? "bg-green-100 text-green-800" :
                          metric.status === "Good" ? "bg-blue-100 text-blue-800" :
                          metric.status === "Fair" ? "bg-yellow-100 text-yellow-800" :
                          "bg-red-100 text-red-800"
                        }`}>
                          {metric.status}
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

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>SIP Monitoring</CardTitle>
            <CardDescription>Monitor SIP server performance</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex justify-between">
              <span>Registrations</span>
              <span className="font-bold text-green-600">2,456</span>
            </div>
            <div className="flex justify-between">
              <span>Active Sessions</span>
              <span className="font-bold">1,247</span>
            </div>
            <div className="flex justify-between">
              <span>Failed Registrations</span>
              <span className="font-bold text-red-600">23</span>
            </div>
            <div className="flex justify-between">
              <span>CPU Usage</span>
              <span className="font-bold">45%</span>
            </div>
            <Progress value={45} />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Network Health</CardTitle>
            <CardDescription>Network infrastructure status</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex justify-between">
              <span>Bandwidth Usage</span>
              <span className="font-bold">756 Mbps</span>
            </div>
            <div className="flex justify-between">
              <span>Packet Loss</span>
              <span className="font-bold text-yellow-600">0.12%</span>
            </div>
            <div className="flex justify-between">
              <span>Uptime</span>
              <span className="font-bold text-green-600">99.98%</span>
            </div>
            <div className="flex justify-between">
              <span>Memory Usage</span>
              <span className="font-bold">68%</span>
            </div>
            <Progress value={68} />
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default QualityMonitoring;
