
const API_BASE_URL = '/api';

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

    const fullUrl = `${API_BASE_URL}${endpoint}`;
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
        const error = await response.json().catch(() => ({ error: 'Network error' }));
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
    return this.request('/dashboard/stats');
  }

  async getCustomers() {
    console.log('ApiClient.getCustomers() called');
    return this.request('/customers');
  }

  async getCDR(params?: { page?: number; limit?: number; accountcode?: string }) {
    const queryParams = new URLSearchParams();
    if (params?.page) queryParams.append('page', params.page.toString());
    if (params?.limit) queryParams.append('limit', params.limit.toString());
    if (params?.accountcode) queryParams.append('accountcode', params.accountcode);
    
    const query = queryParams.toString();
    return this.request(`/cdr${query ? `?${query}` : ''}`);
  }

  // DID Management
  async getDIDs() {
    return this.request('/dids');
  }

  async createDID(did: any) {
    return this.request('/dids', {
      method: 'POST',
      body: JSON.stringify(did),
    });
  }

  async updateDID(did: any) {
    return this.request(`/dids/${did.number}`, {
      method: 'PUT',
      body: JSON.stringify(did),
    });
  }

  // Trunk Management
  async getTrunks() {
    return this.request('/trunks');
  }

  async createTrunk(trunk: any) {
    return this.request('/trunks', {
      method: 'POST',
      body: JSON.stringify(trunk),
    });
  }

  async updateTrunk(trunk: any) {
    return this.request(`/trunks/${trunk.name}`, {
      method: 'PUT',
      body: JSON.stringify(trunk),
    });
  }

  // Route Management
  async getRoutes() {
    return this.request('/routes');
  }

  async createRoute(route: any) {
    return this.request('/routes', {
      method: 'POST',
      body: JSON.stringify(route),
    });
  }

  async updateRoute(route: any) {
    return this.request(`/routes/${route.id}`, {
      method: 'PUT',
      body: JSON.stringify(route),
    });
  }

  // Invoice Management
  async getAllInvoices() {
    return this.request('/invoices');
  }

  async getCustomerInvoices() {
    return this.request('/invoices/customer');
  }

  async createInvoice(invoice: any) {
    return this.request('/invoices', {
      method: 'POST',
      body: JSON.stringify(invoice),
    });
  }

  // Billing Plans
  async getBillingPlans() {
    return this.request('/billing/plans');
  }

  async createBillingPlan(plan: any) {
    return this.request('/billing/plans', {
      method: 'POST',
      body: JSON.stringify(plan),
    });
  }

  async updateBillingPlan(plan: any) {
    return this.request(`/billing/plans/${plan.id}`, {
      method: 'PUT',
      body: JSON.stringify(plan),
    });
  }

  async deleteBillingPlan(planId: string) {
    return this.request(`/billing/plans/${planId}`, {
      method: 'DELETE',
    });
  }

  // Credit refill
  async processRefill(customerId: string, amount: number) {
    return this.request('/billing/refill', {
      method: 'POST',
      body: JSON.stringify({ customerId, amount }),
    });
  }

  // Rate Management
  async getRates() {
    return this.request('/rates');
  }

  async createRate(rate: any) {
    return this.request('/rates', {
      method: 'POST',
      body: JSON.stringify(rate),
    });
  }

  async updateRate(rate: any) {
    return this.request(`/rates/${rate.id}`, {
      method: 'PUT',
      body: JSON.stringify(rate),
    });
  }

  async deleteRate(rateId: string) {
    return this.request(`/rates/${rateId}`, {
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
    return this.request(`/call-quality${query ? `?${query}` : ''}`);
  }

  // SMS Management
  async getSMSHistory(params?: { page?: number; limit?: number; search?: string }) {
    const queryParams = new URLSearchParams();
    if (params?.page) queryParams.append('page', params.page.toString());
    if (params?.limit) queryParams.append('limit', params.limit.toString());
    if (params?.search) queryParams.append('search', params.search);
    
    const query = queryParams.toString();
    return this.request(`/sms${query ? `?${query}` : ''}`);
  }

  async sendSMS(smsData: any) {
    return this.request('/sms/send', {
      method: 'POST',
      body: JSON.stringify(smsData),
    });
  }

  async getSMSTemplates() {
    return this.request('/sms/templates');
  }

  async createSMSTemplate(template: any) {
    return this.request('/sms/templates', {
      method: 'POST',
      body: JSON.stringify(template),
    });
  }

  async getSMSStats() {
    return this.request('/sms/stats');
  }

  logout() {
    localStorage.removeItem('authToken');
    localStorage.removeItem('userRole');
    localStorage.removeItem('username');
  }
}

export const apiClient = new ApiClient();
