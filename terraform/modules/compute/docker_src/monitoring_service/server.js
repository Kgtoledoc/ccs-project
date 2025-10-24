const express = require('express');
const AWS = require('aws-sdk');
const app = express();

const dynamodb = new AWS.DynamoDB.DocumentClient();
const elasticache = require('redis').createClient({
    host: process.env.REDIS_HOST,
    port: 6379
});

app.use(express.json());

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'healthy', service: 'monitoring' });
});

// Get vehicle current status
app.get('/api/vehicles/:vehicleId', async (req, res) => {
    try {
        const { vehicleId } = req.params;
        
        // Try cache first
        const cached = await elasticache.get(`vehicle:${vehicleId}`);
        if (cached) {
            return res.json(JSON.parse(cached));
        }
        
        // Query DynamoDB
        const result = await dynamodb.query({
            TableName: process.env.DYNAMODB_TELEMETRY_TABLE,
            KeyConditionExpression: 'vehicle_id = :vid',
            ExpressionAttributeValues: {
                ':vid': vehicleId
            },
            Limit: 1,
            ScanIndexForward: false
        }).promise();
        
        if (result.Items.length > 0) {
            const vehicle = result.Items[0];
            // Cache for 30 seconds
            await elasticache.setex(`vehicle:${vehicleId}`, 30, JSON.stringify(vehicle));
            res.json(vehicle);
        } else {
            res.status(404).json({ error: 'Vehicle not found' });
        }
    } catch (error) {
        console.error('Error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get multiple vehicles
app.post('/api/vehicles/batch', async (req, res) => {
    try {
        const { vehicleIds } = req.body;
        const vehicles = [];
        
        for (const vehicleId of vehicleIds) {
            const result = await dynamodb.query({
                TableName: process.env.DYNAMODB_TELEMETRY_TABLE,
                KeyConditionExpression: 'vehicle_id = :vid',
                ExpressionAttributeValues: {
                    ':vid': vehicleId
                },
                Limit: 1,
                ScanIndexForward: false
            }).promise();
            
            if (result.Items.length > 0) {
                vehicles.push(result.Items[0]);
            }
        }
        
        res.json({ vehicles });
    } catch (error) {
        console.error('Error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Monitoring service listening on port ${PORT}`);
});

