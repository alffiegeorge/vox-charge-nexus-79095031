const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://172.31.10.10';

export interface LoginCredentials {
  username: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  user: {
    id: number;
    username: string;
    role: string;
    email: string;
  };
}

export class ApiClient {
  private getAuthToken(): string | null {
    return localStorage.getItem('authToken');
  }

  private async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const token = this.getAuthToken();
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      ...(options.headers as Record<string, string>),
    };

    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    // Ensure the endpoint starts with /api/ for API calls (except auth routes)
    let fullUrl = `${API_BASE_URL}${endpoint}`;
    if (endpoint.startsWith('/api/') || endpoint.startsWith('/auth/') || endpoint.startsWith('/health')) {
      fullUrl = `${API_BASE_URL}${endpoint}`;
    } else {
      // This shouldn't happen with our current setup, but just in case
      fullUrl = `${API_BASE_URL}/api${endpoint}`;
    }

    console.log(`API Request: ${options.method || 'GET'} ${fullUrl}`);
    console.log('Request headers:', headers);
    console.log('Auth token exists:', !!token);

    try {
      const response = await fetch(fullUrl, {
        ...options,
        headers,
      });

      console.log(`API Response: ${response.status} ${response.statusText}`);
      console.log('Response headers:', Object.fromEntries(response.headers.entries()));

      if (!response.ok) {
        let error;
        try {
          error = await response.json();
        } catch {
          error = { error: `HTTP ${response.status}: ${response.statusText}` };
        }
        console.error('API Error response:', error);
        throw new Error(error.error || `HTTP ${response.status}`);
      }

      const data = await response.json();
      console.log('API Response data:', data);
      return data;
    } catch (fetchError) {
      console.error('API Fetch error:', fetchError);
      throw fetchError;
    }
  }

  async login(credentials: LoginCredentials): Promise<LoginResponse> {
    return this.request<LoginResponse>('/auth/login', {
      method: 'POST',
      body: JSON.stringify(credentials),
    });
  }

  async getHealthStatus() {
    return this.request('/health');
  }

  async getDashboardStats() {
    return this.request('/api/dashboard/stats');
  }

  async getCustomers() {
    console.log('ApiClient.getCustomers() called');
    return this.request('/api/customers');
  }

  async createCustomer(customerData: any) {
    console.log('ApiClient.createCustomer() called with:', customerData);
    return this.request('/api/customers', {
      method: 'POST',
      body: JSON.stringify(customerData),
    });
  }

  async updateCustomer(customerId: string, customerData: any) {
    console.log('ApiClient.updateCustomer() called with:', customerId, customerData);
    return this.request(`/api/customers/${customerId}`, {
      method: 'PUT',
      body: JSON.stringify(customerData),
    });
  }

  async getCDR(params?: { page?: number; limit?: number; accountcode?: string }) {
    const queryParams = new URLSearchParams();
    if (params?.page) queryParams.append('page', params.page.toString());
    if (params?.limit) queryParams.append('limit', params.limit.toString());
    if (params?.accountcode) queryParams.append('accountcode', params.accountcode);
    
    const query = queryParams.toString();
    return this.request(`/api/cdr${query ? `?${query}` : ''}`);
  }

  // DID Management
  async getDIDs() {
    return this.request('/api/dids');
  }

  async createDID(did: any) {
    return this.request('/api/dids', {
      method: 'POST',
      body: JSON.stringify(did),
    });
  }

  async updateDID(did: any) {
    return this.request(`/api/dids/${did.number}`, {
      method: 'PUT',
      body: JSON.stringify(did),
    });
  }

  // Trunk Management
  async getTrunks() {
    return this.request('/api/trunks');
  }

  async createTrunk(trunk: any) {
    return this.request('/api/trunks', {
      method: 'POST',
      body: JSON.stringify(trunk),
    });
  }

  async updateTrunk(trunk: any) {
    return this.request(`/api/trunks/${trunk.name}`, {
      method: 'PUT',
      body: JSON.stringify(trunk),
    });
  }

  // Route Management
  async getRoutes() {
    return this.request('/api/routes');
  }

  async createRoute(route: any) {
    return this.request('/api/routes', {
      method: 'POST',
      body: JSON.stringify(route),
    });
  }

  async updateRoute(route: any) {
    return this.request(`/api/routes/${route.id}`, {
      method: 'PUT',
      body: JSON.stringify(route),
    });
  }

  // Invoice Management
  async getAllInvoices() {
    return this.request('/api/invoices');
  }

  async getCustomerInvoices() {
    return this.request('/api/invoices/customer');
  }

  async createInvoice(invoice: any) {
    return this.request('/api/invoices', {
      method: 'POST',
      body: JSON.stringify(invoice),
    });
  }

  // Billing Plans
  async getBillingPlans() {
    return this.request('/api/billing/plans');
  }

  async createBillingPlan(plan: any) {
    return this.request('/api/billing/plans', {
      method: 'POST',
      body: JSON.stringify(plan),
    });
  }

  async updateBillingPlan(plan: any) {
    return this.request(`/api/billing/plans/${plan.id}`, {
      method: 'PUT',
      body: JSON.stringify(plan),
    });
  }

  async deleteBillingPlan(planId: string) {
    return this.request(`/api/billing/plans/${planId}`, {
      method: 'DELETE',
    });
  }

  // Credit refill
  async processRefill(customerId: string, amount: number) {
    return this.request('/api/billing/refill', {
      method: 'POST',
      body: JSON.stringify({ customerId, amount }),
    });
  }

  // Rate Management
  async getRates() {
    return this.request('/api/rates');
  }

  async createRate(rate: any) {
    return this.request('/api/rates', {
      method: 'POST',
      body: JSON.stringify(rate),
    });
  }

  async updateRate(rate: any) {
    return this.request(`/api/rates/${rate.id}`, {
      method: 'PUT',
      body: JSON.stringify(rate),
    });
  }

  async deleteRate(rateId: string) {
    return this.request(`/api/rates/${rateId}`, {
      method: 'DELETE',
    });
  }

  // Call Quality Management
  async getCallQuality(params?: { page?: number; limit?: number; date?: string }) {
    const queryParams = new URLSearchParams();
    if (params?.page) queryParams.append('page', params.page.toString());
    if (params?.limit) queryParams.append('limit', params.limit.toString());
    if (params?.date) queryParams.append('date', params.date);
    
    const query = queryParams.toString();
    return this.request(`/api/call-quality${query ? `?${query}` : ''}`);
  }

  // SMS Management
  async getSMSHistory(params?: { page?: number; limit?: number; search?: string }) {
    const queryParams = new URLSearchParams();
    if (params?.page) queryParams.append('page', params.page.toString());
    if (params?.limit) queryParams.append('limit', params.limit.toString());
    if (params?.search) queryParams.append('search', params.search);
    
    const query = queryParams.toString();
    return this.request(`/api/sms${query ? `?${query}` : ''}`);
  }

  async sendSMS(smsData: any) {
    return this.request('/api/sms/send', {
      method: 'POST',
      body: JSON.stringify(smsData),
    });
  }

  async getSMSTemplates() {
    return this.request('/api/sms/templates');
  }

  async createSMSTemplate(template: any) {
    return this.request('/api/sms/templates', {
      method: 'POST',
      body: JSON.stringify(template),
    });
  }

  async getSMSStats() {
    return this.request('/api/sms/stats');
  }

  logout() {
    localStorage.removeItem('authToken');
    localStorage.removeItem('userRole');
    localStorage.removeItem('username');
  }
}

export const apiClient = new ApiClient();

export default apiClient;
