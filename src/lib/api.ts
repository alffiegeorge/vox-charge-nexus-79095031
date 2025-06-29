const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://172.31.10.10:3001';

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

  // Make the request method public so it can be used directly
  async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const token = this.getAuthToken();
    
    // Initialize headers properly
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };

    // Add any existing headers from options
    if (options.headers) {
      Object.assign(headers, options.headers);
    }

    // Add Authorization header if token exists
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
      console.log('Adding Authorization header with token');
    } else {
      console.warn('No auth token found for request to:', endpoint);
    }

    // Construct the full URL
    let fullUrl = `${API_BASE_URL}${endpoint}`;

    console.log(`API Request: ${options.method || 'GET'} ${fullUrl}`);
    console.log('Request headers:', headers);
    console.log('Auth token exists:', !!token);

    try {
      const response = await fetch(fullUrl, {
        ...options,
        headers,
        mode: 'cors', // Explicitly set CORS mode
        credentials: 'omit', // Don't send credentials for CORS
      });

      console.log(`API Response: ${response.status} ${response.statusText}`);
      console.log('Response headers:', Object.fromEntries(response.headers.entries()));

      if (!response.ok) {
        let error;
        try {
          error = await response.json();
        } catch {
          // If we can't parse JSON, create a generic error
          if (response.status === 0 || response.status >= 500) {
            error = { error: 'Unable to connect to server. Please check if the backend is running.' };
          } else {
            error = { error: `HTTP ${response.status}: ${response.statusText}` };
          }
        }
        console.error('API Error response:', error);
        throw new Error(error.error || `HTTP ${response.status}`);
      }

      const data = await response.json();
      console.log('API Response data:', data);
      return data;
    } catch (fetchError) {
      console.error('API Fetch error:', fetchError);
      
      // Check if it's a network error
      if (fetchError instanceof TypeError && fetchError.message.includes('fetch')) {
        throw new Error('Unable to connect to server. Please check your network connection and ensure the backend is running.');
      }
      
      throw fetchError;
    }
  }

  async login(credentials: LoginCredentials): Promise<LoginResponse> {
    console.log('Attempting login with API_BASE_URL:', API_BASE_URL);
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

  // DID Management with assignment functionality
  async getDIDs() {
    console.log('ApiClient.getDIDs() called');
    return this.request('/api/dids');
  }

  async createDID(did: any) {
    console.log('Creating DID with assignment:', did);
    return this.request('/api/dids', {
      method: 'POST',
      body: JSON.stringify(did),
    });
  }

  async updateDID(did: any) {
    console.log('Updating DID with assignment:', did);
    return this.request(`/api/dids/${encodeURIComponent(did.number)}`, {
      method: 'PUT',
      body: JSON.stringify(did),
    });
  }

  async assignDIDToCustomer(didNumber: string, customerId: string) {
    console.log('Assigning DID to customer:', didNumber, customerId);
    return this.request(`/api/dids/${encodeURIComponent(didNumber)}/assign`, {
      method: 'POST',
      body: JSON.stringify({ customerId }),
    });
  }

  async unassignDID(didNumber: string) {
    console.log('Unassigning DID:', didNumber);
    return this.request(`/api/dids/${encodeURIComponent(didNumber)}/unassign`, {
      method: 'POST',
    });
  }

  async getCustomerDIDs(customerId: string) {
    console.log('Getting DIDs for customer:', customerId);
    return this.request(`/api/dids/customer/${customerId}`);
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

  async createSipEndpoint(customerId: string) {
    return this.request(`/api/customers/${customerId}/create-sip-endpoint`, {
      method: 'POST',
    });
  }

  logout() {
    localStorage.removeItem('authToken');
    localStorage.removeItem('userRole');
    localStorage.removeItem('username');
  }
}

export const apiClient = new ApiClient();

export default apiClient;
