// Anomaly Detector Lambda Function
const AWS = require('aws-sdk');
const sqs = new AWS.SQS();

exports.handler = async (event) => {
    console.log('Analyzing for anomalies:', JSON.stringify(event));
    
    try {
        const telemetry = event;
        const anomalies = [];
        
        // Simple anomaly detection rules
        if (telemetry.speed > 120) {
            anomalies.push({
                type: 'excessive_speed',
                severity: 'high',
                value: telemetry.speed,
                threshold: 120
            });
        }
        
        if (telemetry.cargo_temperature && telemetry.cargo_temperature > 30) {
            anomalies.push({
                type: 'high_temperature',
                severity: 'medium',
                value: telemetry.cargo_temperature,
                threshold: 30
            });
        }
        
        // Check for long idle (speed = 0 for extended period)
        if (telemetry.speed === 0 && telemetry.engine_status === 'on') {
            anomalies.push({
                type: 'long_idle',
                severity: 'low',
                message: 'Vehicle idle with engine running'
            });
        }
        
        // If critical anomaly detected, send to emergency queue
        const criticalAnomalies = anomalies.filter(a => a.severity === 'high');
        
        if (criticalAnomalies.length > 0) {
            console.log('Critical anomaly detected, escalating to emergency queue');
            
            await sqs.sendMessage({
                QueueUrl: process.env.EMERGENCY_QUEUE_URL,
                MessageBody: JSON.stringify({
                    vehicleId: telemetry.vehicleId,
                    type: 'critical_anomaly',
                    severity: 'critical',
                    anomalies: criticalAnomalies,
                    location: telemetry.location,
                    timestamp: Date.now()
                }),
                MessageGroupId: telemetry.vehicleId,
                MessageDeduplicationId: `${telemetry.vehicleId}-${Date.now()}`
            }).promise();
        }
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                vehicleId: telemetry.vehicleId,
                anomalies: anomalies,
                escalated: criticalAnomalies.length > 0
            })
        };
        
    } catch (error) {
        console.error('Error detecting anomalies:', error);
        throw error;
    }
};

