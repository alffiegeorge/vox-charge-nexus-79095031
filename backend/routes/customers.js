
const express = require('express');
const router = express.Router();
const { executeQuery } = require('../database');

// Get all customers
router.get('/', async (req, res) => {
    try {
        const customers = await executeQuery(`
            SELECT c.*, 
                   COUNT(dn.number) as assigned_dids,
                   sc.sip_username,
                   sc.status as sip_status
            FROM customers c
            LEFT JOIN did_numbers dn ON c.id = dn.customer_id
            LEFT JOIN sip_credentials sc ON c.id = sc.customer_id
            GROUP BY c.id
            ORDER BY c.created_at DESC
        `);
        
        res.json(customers[0] || []);
    } catch (error) {
        console.error('Error fetching customers:', error);
        res.status(500).json({ error: 'Failed to fetch customers' });
    }
});

// Get customer by ID
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const customers = await executeQuery(`
            SELECT c.*, 
                   sc.sip_username,
                   sc.status as sip_status
            FROM customers c
            LEFT JOIN sip_credentials sc ON c.id = sc.customer_id
            WHERE c.id = ?
        `, [id]);
        
        if (customers[0].length === 0) {
            return res.status(404).json({ error: 'Customer not found' });
        }
        
        res.json(customers[0][0]);
    } catch (error) {
        console.error('Error fetching customer:', error);
        res.status(500).json({ error: 'Failed to fetch customer' });
    }
});

// Create new customer
router.post('/', async (req, res) => {
    try {
        const { name, email, phone, company, address, status = 'active', credit_limit = 0.00 } = req.body;
        
        if (!name || !email) {
            return res.status(400).json({ error: 'Name and email are required' });
        }
        
        // Generate customer ID
        const customerId = `c${Date.now()}`;
        
        // Insert customer
        await executeQuery(`
            INSERT INTO customers (id, name, email, phone, company, address, status, credit_limit, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
        `, [customerId, name, email, phone, company, address, status, credit_limit]);
        
        // Get the created customer
        const newCustomer = await executeQuery(`
            SELECT * FROM customers WHERE id = ?
        `, [customerId]);
        
        res.status(201).json(newCustomer[0][0]);
    } catch (error) {
        console.error('Error creating customer:', error);
        if (error.code === 'ER_DUP_ENTRY') {
            res.status(400).json({ error: 'Customer with this email already exists' });
        } else {
            res.status(500).json({ error: 'Failed to create customer' });
        }
    }
});

// Update customer
router.put('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const { name, email, phone, company, address, status, credit_limit } = req.body;
        
        // Check if customer exists
        const existing = await executeQuery('SELECT id FROM customers WHERE id = ?', [id]);
        if (existing[0].length === 0) {
            return res.status(404).json({ error: 'Customer not found' });
        }
        
        // Update customer
        await executeQuery(`
            UPDATE customers 
            SET name = ?, email = ?, phone = ?, company = ?, address = ?, status = ?, credit_limit = ?, updated_at = NOW()
            WHERE id = ?
        `, [name, email, phone, company, address, status, credit_limit, id]);
        
        // Get updated customer
        const updated = await executeQuery('SELECT * FROM customers WHERE id = ?', [id]);
        res.json(updated[0][0]);
    } catch (error) {
        console.error('Error updating customer:', error);
        res.status(500).json({ error: 'Failed to update customer' });
    }
});

// Create SIP endpoint for customer
router.post('/:id/create-sip-endpoint', async (req, res) => {
    try {
        const { id } = req.params;
        
        // Check if customer exists
        const customer = await executeQuery('SELECT * FROM customers WHERE id = ?', [id]);
        if (customer[0].length === 0) {
            return res.status(404).json({ error: 'Customer not found' });
        }
        
        // Check if SIP endpoint already exists
        const existing = await executeQuery('SELECT * FROM sip_credentials WHERE customer_id = ?', [id]);
        if (existing[0].length > 0) {
            return res.status(400).json({ error: 'SIP endpoint already exists for this customer' });
        }
        
        // Generate SIP username and password
        const sipUsername = id; // Use customer ID as SIP username
        const sipPassword = Math.random().toString(36).substring(2, 15);
        
        // Create SIP credentials
        await executeQuery(`
            INSERT INTO sip_credentials (customer_id, sip_username, sip_password, status, created_at, updated_at)
            VALUES (?, ?, ?, 'active', NOW(), NOW())
        `, [id, sipUsername, sipPassword]);
        
        // Create PJSIP endpoint configuration
        await executeQuery(`
            INSERT INTO ps_endpoints (id, transport, aors, auth, context, disallow, allow, direct_media)
            VALUES (?, 'transport-udp', ?, ?, 'from-internal', 'all', 'ulaw,alaw,g729', 'no')
        `, [sipUsername, sipUsername, sipUsername]);
        
        // Create PJSIP AOR
        await executeQuery(`
            INSERT INTO ps_aors (id, max_contacts, remove_existing)
            VALUES (?, 1, 'yes')
        `, [sipUsername]);
        
        // Create PJSIP Auth
        await executeQuery(`
            INSERT INTO ps_auths (id, auth_type, password, username)
            VALUES (?, 'userpass', ?, ?)
        `, [sipUsername, sipPassword, sipUsername]);
        
        res.json({
            message: 'SIP endpoint created successfully',
            sip_username: sipUsername,
            sip_password: sipPassword
        });
    } catch (error) {
        console.error('Error creating SIP endpoint:', error);
        res.status(500).json({ error: 'Failed to create SIP endpoint' });
    }
});

module.exports = router;
