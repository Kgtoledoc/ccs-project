// Telemetry Processor Lambda Function
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();
const timestream = new AWS.TimestreamWrite();

exports.handler = async (event) => {
    console.log('Processing telemetry batch:', event.Records.length);
    
    const processedRecords = [];
    
    for (const record of event.Records) {
        try {
            // Decode Kinesis data
            const payload = Buffer.from(record.kinesis.data, 'base64').toString('utf-8');
            const telemetry = JSON.parse(payload);
            
            console.log('Processing vehicle:', telemetry.vehicleId);
            
            // Store in DynamoDB (current state)
            await dynamodb.put({
                TableName: process.env.DYNAMODB_TELEMETRY_TABLE,
                Item: {
                    vehicle_id: telemetry.vehicleId,
                    timestamp: telemetry.timestamp || Date.now(),
                    location: telemetry.location,
                    speed: telemetry.speed,
                    direction: telemetry.direction,
                    cargo_temperature: telemetry.cargo_temperature,
                    status: telemetry.speed > 0 ? 'moving' : 'stopped',
                    ttl: Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60) // 90 days
                }
            }).promise();
            
            // Store in Timestream (time-series)
            const timestreamRecords = [{
                Time: telemetry.timestamp.toString(),
                TimeUnit: 'MILLISECONDS',
                Dimensions: [
                    { Name: 'vehicle_id', Value: telemetry.vehicleId },
                    { Name: 'region', Value: 'us-east-1' }
                ],
                MeasureName: 'vehicle_metrics',
                MeasureValueType: 'MULTI',
                MeasureValues: [
                    { Name: 'speed', Value: telemetry.speed?.toString() || '0', Type: 'DOUBLE' },
                    { Name: 'cargo_temperature', Value: telemetry.cargo_temperature?.toString() || '0', Type: 'DOUBLE' }
                ]
            }];
            
            await timestream.writeRecords({
                DatabaseName: process.env.TIMESTREAM_DATABASE,
                TableName: process.env.TIMESTREAM_TABLE,
                Records: timestreamRecords
            }).promise();
            
            processedRecords.push(telemetry.vehicleId);
            
        } catch (error) {
            console.error('Error processing record:', error);
            // Continue processing other records
        }
    }
    
    console.log(`Successfully processed ${processedRecords.length} records`);
    
    return {
        statusCode: 200,
        body: JSON.stringify({
            processed: processedRecords.length,
            vehicles: processedRecords
        })
    };
};

