// WebSocket Handler Lambda Function
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();
const apigateway = new AWS.ApiGatewayManagementApi({
    endpoint: process.env.WEBSOCKET_ENDPOINT
});

exports.handler = async (event) => {
    const { routeKey, connectionId } = event.requestContext;
    
    console.log('WebSocket event:', routeKey, connectionId);
    
    try {
        switch (routeKey) {
            case '$connect':
                return await handleConnect(connectionId, event);
            
            case '$disconnect':
                return await handleDisconnect(connectionId);
            
            case 'subscribe':
                return await handleSubscribe(connectionId, event);
            
            case 'ping':
                return { statusCode: 200, body: 'pong' };
            
            default:
                return { statusCode: 400, body: 'Unknown route' };
        }
    } catch (error) {
        console.error('WebSocket error:', error);
        return { statusCode: 500, body: 'Internal error' };
    }
};

async function handleConnect(connectionId, event) {
    console.log('New connection:', connectionId);
    
    const item = {
        connection_id: connectionId,
        connected_at: Date.now(),
        ttl: Math.floor(Date.now() / 1000) + (24 * 60 * 60) // 24 hours
    };
    
    // Extract user info from query parameters if available
    if (event.queryStringParameters && event.queryStringParameters.userId) {
        item.user_id = event.queryStringParameters.userId;
    }
    
    await dynamodb.put({
        TableName: process.env.CONNECTIONS_TABLE,
        Item: item
    }).promise();
    
    return { statusCode: 200, body: 'Connected' };
}

async function handleDisconnect(connectionId) {
    console.log('Disconnecting:', connectionId);
    
    await dynamodb.delete({
        TableName: process.env.CONNECTIONS_TABLE,
        Key: { connection_id: connectionId }
    }).promise();
    
    return { statusCode: 200, body: 'Disconnected' };
}

async function handleSubscribe(connectionId, event) {
    const body = JSON.parse(event.body);
    const { vehicleIds } = body;
    
    console.log('Subscribe to vehicles:', vehicleIds);
    
    await dynamodb.update({
        TableName: process.env.CONNECTIONS_TABLE,
        Key: { connection_id: connectionId },
        UpdateExpression: 'SET subscribed_vehicles = :vehicles',
        ExpressionAttributeValues: {
            ':vehicles': vehicleIds
        }
    }).promise();
    
    return { 
        statusCode: 200, 
        body: JSON.stringify({ 
            message: 'Subscribed',
            vehicles: vehicleIds 
        }) 
    };
}

// Helper function to broadcast updates (called by DynamoDB Stream)
async function broadcastUpdate(vehicleId, data) {
    // Get all connections subscribed to this vehicle
    const result = await dynamodb.scan({
        TableName: process.env.CONNECTIONS_TABLE,
        FilterExpression: 'contains(subscribed_vehicles, :vehicleId)',
        ExpressionAttributeValues: {
            ':vehicleId': vehicleId
        }
    }).promise();
    
    const postCalls = result.Items.map(async ({ connection_id }) => {
        try {
            await apigateway.postToConnection({
                ConnectionId: connection_id,
                Data: JSON.stringify({
                    type: 'vehicle_update',
                    vehicleId: vehicleId,
                    data: data
                })
            }).promise();
        } catch (error) {
            if (error.statusCode === 410) {
                // Connection is stale, delete it
                await dynamodb.delete({
                    TableName: process.env.CONNECTIONS_TABLE,
                    Key: { connection_id }
                }).promise();
            }
        }
    });
    
    await Promise.all(postCalls);
}

