const express = require('express');
const router = express.Router();
const { executeQuery } = require('../database');
const { reloadAsteriskConfig } = require('../asterisk-manager');

// Get all DIDs
router.get('/', async (req, res) => {
  try {
    console.log('=== DID API: Fetching all DIDs from database ===');
    
    const result = await executeQuery(`
      SELECT 
        d.id,
        d.number,
        d.customer_name,
        d.country,
        d.rate,
        d.type,
        d.status,
        d.notes,
        d.created_at,
        d.updated_at,
        d.customer_id,
        c.name as assigned_customer_name,
        c.email as customer_email
      FROM did_numbers d
      LEFT JOIN customers c ON d.customer_id = c.id
      ORDER BY d.created_at DESC
    `);

    console.log('DID query result structure:', {
      resultLength: result.length,
      firstResult: result[0] ? 'exists' : 'null',
      firstResultLength: result[0] ? result[0].length : 'N/A'
    });

    // The result from executeQuery returns [rows, fields]
    const dids = result[0] || [];
    
    console.log(`Found ${dids.length} DIDs in database`);
    
    if (dids.length > 0) {
      console.log('Sample DID data:', JSON.stringify(dids[0], null, 2));
    }
    
    const formattedDids = dids.map(did => ({
      id: did.id,
      number: did.number,
      customer_name: did.assigned_customer_name || did.customer_name || 'Unassigned',
      customer: did.assigned_customer_name || did.customer_name || 'Unassigned',
      country: did.country,
      rate: did.rate,
      type: did.type,
      status: did.status,
      notes: did.notes,
      customer_id: did.customer_id,
      created_at: did.created_at,
      updated_at: did.updated_at
    }));

    console.log('Formatted DIDs to send:', formattedDids.length);
    console.log('=== DID API: Response ready ===');

    res.json(formattedDids);
  } catch (error) {
    console.error('=== DID API ERROR ===');
    console.error('Error fetching DIDs:', error);
    console.error('Error details:', {
      message: error.message,
      code: error.code,
      sqlState: error.sqlState
    });
    res.status(500).json({ error: 'Failed to fetch DIDs', details: error.message });
  }
});

// Create new DID
router.post('/', async (req, res) => {
  try {
    const { number, customer, country, rate, type, status, customerId, notes } = req.body;
    
    console.log('Creating new DID:', { number, customer, country, rate, type, status, customerId });

    // Validate required fields
    if (!number || !country || !rate || !type) {
      return res.status(400).json({ error: 'Missing required fields: number, country, rate, type' });
    }

    // Check if DID already exists
    const existingDid = await executeQuery('SELECT id FROM did_numbers WHERE number = ?', [number]);
    if (existingDid.length > 0) {
      return res.status(409).json({ error: 'DID number already exists' });
    }

    // Determine customer assignment
    let customerName = 'Unassigned';
    let finalCustomerId = null;
    let finalStatus = 'Available';

    if (customerId && customerId !== 'unassigned') {
      // Verify customer exists
      const customerData = await executeQuery('SELECT id, name FROM customers WHERE id = ?', [customerId]);
      if (customerData.length === 0) {
        return res.status(404).json({ error: 'Customer not found' });
      }
      
      customerName = customerData[0].name;
      finalCustomerId = customerId;
      finalStatus = 'Active';
      
      console.log(`Assigning DID ${number} to customer ${customerName} (${customerId})`);
    }

    // Insert DID into database
    const result = await executeQuery(`
      INSERT INTO did_numbers (number, customer_name, country, rate, type, status, customer_id, notes, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    `, [number, customerName, country, rate, type, finalStatus, finalCustomerId, notes || '']);

    console.log('DID created successfully with ID:', result.insertId);

    // Update Asterisk dialplan if DID is assigned to customer
    if (finalCustomerId) {
      await updateAsteriskDialplan(number, finalCustomerId);
    }

    res.status(201).json({
      id: result.insertId,
      number,
      customer_name: customerName,
      country,
      rate,
      type,
      status: finalStatus,
      customer_id: finalCustomerId,
      notes: notes || '',
      message: finalCustomerId ? `DID ${number} created and assigned to ${customerName}` : `DID ${number} created and available for assignment`
    });

  } catch (error) {
    console.error('Error creating DID:', error);
    res.status(500).json({ error: 'Failed to create DID' });
  }
});

// Update DID
router.put('/:number', async (req, res) => {
  try {
    const { number } = req.params;
    const { customer, country, rate, type, status, customerId, notes } = req.body;
    
    console.log('Updating DID:', number, req.body);

    // Check if DID exists
    const existingDidResult = await executeQuery('SELECT * FROM did_numbers WHERE number = ?', [number]);
    const existingDid = existingDidResult[0]; // Get the rows array
    
    if (!existingDid || existingDid.length === 0) {
      return res.status(404).json({ error: 'DID not found' });
    }

    // Determine customer assignment
    let customerName = 'Unassigned';
    let finalCustomerId = null;
    let finalStatus = status || 'Available';

    if (customerId && customerId !== 'unassigned') {
      // Verify customer exists and get customer data
      const customerResult = await executeQuery('SELECT id, name FROM customers WHERE id = ?', [customerId]);
      const customerData = customerResult[0]; // Get the rows array
      
      if (!customerData || customerData.length === 0) {
        return res.status(404).json({ error: 'Customer not found' });
      }
      
      customerName = customerData[0].name;
      finalCustomerId = customerId;
      finalStatus = 'Active';
      
      console.log(`Updating DID ${number} assignment to customer ${customerName} (${customerId})`);
    } else {
      console.log(`Unassigning DID ${number}`);
    }

    // Clean and parse the rate value - remove $ sign and convert to number
    let cleanRate = rate;
    if (typeof rate === 'string') {
      cleanRate = rate.replace('$', '').replace(',', '');
    }
    const numericRate = parseFloat(cleanRate) || 0;

    // Update DID in database - make sure no undefined values
    const updateParams = [
      customerName,
      country,
      numericRate, // Use numeric rate instead of string with $
      type,
      finalStatus,
      finalCustomerId,
      notes || '',
      number
    ];

    console.log('Update parameters:', updateParams);

    await executeQuery(`
      UPDATE did_numbers 
      SET customer_name = ?, country = ?, rate = ?, type = ?, status = ?, customer_id = ?, notes = ?, updated_at = NOW()
      WHERE number = ?
    `, updateParams);

    console.log('DID updated successfully');

    // Update Asterisk dialplan
    await updateAsteriskDialplan(number, finalCustomerId);

    res.json({
      number,
      customer_name: customerName,
      country,
      rate: numericRate,
      type,
      status: finalStatus,
      customer_id: finalCustomerId,
      notes: notes || '',
      message: finalCustomerId ? `DID ${number} updated and assigned to ${customerName}` : `DID ${number} updated and unassigned`
    });

  } catch (error) {
    console.error('Error updating DID:', error);
    res.status(500).json({ error: 'Failed to update DID' });
  }
});

// Assign DID to customer
router.post('/:number/assign', async (req, res) => {
  try {
    const { number } = req.params;
    const { customerId } = req.body;
    
    console.log(`Assigning DID ${number} to customer ${customerId}`);

    if (!customerId) {
      return res.status(400).json({ error: 'Customer ID is required' });
    }

    // Check if DID exists
    const existingDid = await executeQuery('SELECT * FROM did_numbers WHERE number = ?', [number]);
    if (existingDid.length === 0) {
      return res.status(404).json({ error: 'DID not found' });
    }

    // Verify customer exists
    const customerData = await executeQuery('SELECT id, name FROM customers WHERE id = ?', [customerId]);
    if (customerData.length === 0) {
      return res.status(404).json({ error: 'Customer not found' });
    }

    const customerName = customerData[0].name;

    // Update DID assignment
    await executeQuery(`
      UPDATE did_numbers 
      SET customer_name = ?, customer_id = ?, status = 'Active', updated_at = NOW()
      WHERE number = ?
    `, [customerName, customerId, number]);

    console.log(`DID ${number} assigned to customer ${customerName} (${customerId})`);

    // Update Asterisk dialplan
    await updateAsteriskDialplan(number, customerId);

    res.json({
      number,
      customer_name: customerName,
      customer_id: customerId,
      status: 'Active',
      message: `DID ${number} assigned to ${customerName}`
    });

  } catch (error) {
    console.error('Error assigning DID:', error);
    res.status(500).json({ error: 'Failed to assign DID' });
  }
});

// Unassign DID
router.post('/:number/unassign', async (req, res) => {
  try {
    const { number } = req.params;
    
    console.log(`Unassigning DID ${number}`);

    // Check if DID exists
    const existingDid = await executeQuery('SELECT * FROM did_numbers WHERE number = ?', [number]);
    if (existingDid.length === 0) {
      return res.status(404).json({ error: 'DID not found' });
    }

    // Update DID assignment
    await executeQuery(`
      UPDATE did_numbers 
      SET customer_name = 'Unassigned', customer_id = NULL, status = 'Available', updated_at = NOW()
      WHERE number = ?
    `, [number]);

    console.log(`DID ${number} unassigned`);

    // Update Asterisk dialplan
    await updateAsteriskDialplan(number, null);

    res.json({
      number,
      customer_name: 'Unassigned',
      customer_id: null,
      status: 'Available',
      message: `DID ${number} unassigned`
    });

  } catch (error) {
    console.error('Error unassigning DID:', error);
    res.status(500).json({ error: 'Failed to unassign DID' });
  }
});

// Get DIDs for specific customer
router.get('/customer/:customerId', async (req, res) => {
  try {
    const { customerId } = req.params;
    
    console.log(`Fetching DIDs for customer ${customerId}`);

    const dids = await executeQuery(`
      SELECT * FROM did_numbers 
      WHERE customer_id = ?
      ORDER BY created_at DESC
    `, [customerId]);

    console.log(`Found ${dids.length} DIDs for customer ${customerId}`);

    res.json(dids);
  } catch (error) {
    console.error('Error fetching customer DIDs:', error);
    res.status(500).json({ error: 'Failed to fetch customer DIDs' });
  }
});

// Helper function to update Asterisk dialplan
async function updateAsteriskDialplan(didNumber, customerId) {
  try {
    console.log(`Updating Asterisk dialplan for DID ${didNumber}`);
    
    if (customerId) {
      // Get customer's SIP username
      const sipCredentials = await executeQuery(
        'SELECT sip_username FROM sip_credentials WHERE customer_id = ? AND status = "active"',
        [customerId]
      );

      if (sipCredentials.length > 0) {
        const sipUsername = sipCredentials[0].sip_username;
        console.log(`DID ${didNumber} will route to SIP endpoint ${sipUsername}`);
        
        // Update database with routing information
        await executeQuery(`
          INSERT INTO did_routes (did_number, destination_type, destination_value, created_at, updated_at)
          VALUES (?, 'sip', ?, NOW(), NOW())
          ON DUPLICATE KEY UPDATE
          destination_value = VALUES(destination_value), updated_at = NOW()
        `, [didNumber, sipUsername]);
        
        console.log(`DID route created: ${didNumber} -> ${sipUsername}`);
      } else {
        console.warn(`Customer ${customerId} has no active SIP endpoint`);
      }
    } else {
      // Remove routing for unassigned DID
      await executeQuery('DELETE FROM did_routes WHERE did_number = ?', [didNumber]);
      console.log(`DID route removed for ${didNumber}`);
    }

    // Reload Asterisk dialplan to pick up changes
    await reloadAsteriskConfig();
    
  } catch (error) {
    console.error('Error updating Asterisk dialplan:', error);
    // Don't throw error - DID operations should succeed even if Asterisk update fails
  }
}

module.exports = router;
