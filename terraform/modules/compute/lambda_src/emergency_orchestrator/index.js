// Emergency Orchestrator Lambda Function
const AWS = require('aws-sdk');
const stepfunctions = new AWS.StepFunctions();

exports.handler = async (event) => {
    console.log('Emergency event received:', JSON.stringify(event));
    
    try {
        // Parse SQS message
        for (const record of event.Records) {
            const message = JSON.parse(record.body);
            
            console.log('Processing emergency:', message.type, 'for vehicle:', message.vehicleId);
            
            // Start Step Functions workflow
            const params = {
                stateMachineArn: process.env.EMERGENCY_WORKFLOW_ARN,
                input: JSON.stringify({
                    vehicleId: message.vehicleId,
                    type: message.type,
                    severity: message.severity || 'critical',
                    location: message.location,
                    eventTimestamp: message.timestamp || Date.now(),
                    metadata: message.metadata || {}
                })
            };
            
            const result = await stepfunctions.startExecution(params).promise();
            
            console.log('Started emergency workflow:', result.executionArn);
        }
        
        return {
            statusCode: 200,
            body: JSON.stringify({ message: 'Emergency workflow initiated' })
        };
        
    } catch (error) {
        console.error('Error processing emergency:', error);
        throw error;
    }
};

