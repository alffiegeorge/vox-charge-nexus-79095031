
const express = require('express');
const router = express.Router();
const { executeQuery } = require('../database');

// Get CDR records with pagination
router.get('/', async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 50;
        const offset = (page - 1) * limit;
        const accountcode = req.query.accountcode;
        
        let whereClause = '';
        let params = [];
        
        if (accountcode) {
            whereClause = 'WHERE accountcode = ?';
            params.push(accountcode);
        }
        
        // Get total count
        const countQuery = `SELECT COUNT(*) as total FROM cdr ${whereClause}`;
        const totalResult = await executeQuery(countQuery, params);
        const total = totalResult[0][0].total;
        
        // Get CDR records
        const cdrQuery = `
            SELECT cdr.*, customers.name as customer_name
            FROM cdr 
            LEFT JOIN customers ON cdr.accountcode = customers.id
            ${whereClause}
            ORDER BY calldate DESC 
            LIMIT ? OFFSET ?
        `;
        params.push(limit, offset);
        
        const cdrResult = await executeQuery(cdrQuery, params);
        const records = cdrResult[0] || [];
        
        res.json({
            records,
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit)
            }
        });
    } catch (error) {
        console.error('Error fetching CDR records:', error);
        res.status(500).json({ error: 'Failed to fetch CDR records' });
    }
});

// Get CDR statistics
router.get('/stats', async (req, res) => {
    try {
        const today = new Date().toISOString().split('T')[0];
        const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
        
        // Total calls today
        const todayCalls = await executeQuery(`
            SELECT COUNT(*) as count FROM cdr 
            WHERE DATE(calldate) = ?
        `, [today]);
        
        // Total calls this month
        const monthCalls = await executeQuery(`
            SELECT COUNT(*) as count FROM cdr 
            WHERE calldate >= ?
        `, [thirtyDaysAgo]);
        
        // Average call duration today
        const avgDuration = await executeQuery(`
            SELECT AVG(duration) as avg_duration FROM cdr 
            WHERE DATE(calldate) = ? AND disposition = 'ANSWERED'
        `, [today]);
        
        // Failed calls today
        const failedCalls = await executeQuery(`
            SELECT COUNT(*) as count FROM cdr 
            WHERE DATE(calldate) = ? AND disposition != 'ANSWERED'
        `, [today]);
        
        res.json({
            todayCalls: todayCalls[0][0].count,
            monthCalls: monthCalls[0][0].count,
            avgDuration: Math.round(avgDuration[0][0].avg_duration || 0),
            failedCalls: failedCalls[0][0].count
        });
    } catch (error) {
        console.error('Error fetching CDR stats:', error);
        res.status(500).json({ error: 'Failed to fetch CDR statistics' });
    }
});

module.exports = router;
