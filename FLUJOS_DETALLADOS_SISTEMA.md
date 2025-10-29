# 🔄 FLUJOS DETALLADOS DEL SISTEMA CCS

**Documento Técnico Completo** - Explicación detallada de todos los flujos de datos y servicios involucrados.

---

## 📋 **ÍNDICE DE FLUJOS**

1. [🚨 Flujo de Emergencia (<2s SLA)](#flujo-de-emergencia)
2. [📊 Flujo de Telemetría Normal](#flujo-de-telemetría-normal)
3. [🔍 Flujo de Detección de Anomalías](#flujo-de-detección-de-anomalías)
4. [🌐 Flujo de Actualizaciones en Tiempo Real](#flujo-de-actualizaciones-en-tiempo-real)
5. [💾 Flujo de Data Lake (Analytics)](#flujo-de-data-lake)
6. [🛒 Flujo de Proceso de Ventas](#flujo-de-proceso-de-ventas)
7. [🔐 Flujo de Autenticación](#flujo-de-autenticación)
8. [📱 Flujo de API REST](#flujo-de-api-rest)
9. [🔌 Flujo de WebSocket](#flujo-de-websocket)
10. [📈 Flujo de GraphQL](#flujo-de-graphql)

---

## 🚨 **FLUJO DE EMERGENCIA (<2s SLA)**

### **Descripción**
Procesamiento ultra-rápido de eventos críticos (botón pánico, accidentes, secuestros) con notificaciones paralelas a autoridades y propietarios.

### **Servicios Involucrados**
- **IoT Core** → **IoT Rules Engine** → **SQS FIFO** → **Lambda Emergency Orchestrator** → **Step Functions** → **SNS** → **DynamoDB**

### **Flujo Detallado**

#### **1. Disparo del Evento (0ms)**
```
Vehículo → Botón Pánico/Sensor → MQTT Publish
Topic: vehicle/{vehicleId}/emergency
Payload: {
  "vehicleId": "VEH-001",
  "type": "panic_button",
  "severity": "critical",
  "location": {"lat": 4.6097, "lon": -74.0817},
  "timestamp": 1698765432000
}
```

#### **2. IoT Rules Engine (50ms)**
```sql
SELECT *, topic(2) as vehicleId, timestamp() as eventTimestamp 
FROM 'vehicle/+/emergency' 
WHERE type IN ('panic_button', 'accident', 'hijack', 'critical_anomaly')
```
- **Filtro**: Solo eventos críticos
- **Enrutamiento**: SQS FIFO para garantizar orden
- **Latencia**: <50ms

#### **3. SQS FIFO Queue (100ms)**
```json
{
  "MessageGroupId": "VEH-001",
  "MessageDeduplicationId": "VEH-001-1698765432000",
  "MessageBody": "{...emergency_data...}"
}
```
- **Garantías**: Exactly-once processing
- **Orden**: Por vehicleId (MessageGroupId)
- **Throughput**: 3,000 msg/seg
- **Latencia**: <100ms

#### **4. Lambda Emergency Orchestrator (200ms)**
```javascript
// emergency_orchestrator/index.js
const params = {
    stateMachineArn: process.env.EMERGENCY_WORKFLOW_ARN,
    input: JSON.stringify({
        vehicleId: message.vehicleId,
        type: message.type,
        severity: message.severity,
        location: message.location,
        eventTimestamp: message.timestamp
    })
};

const result = await stepfunctions.startExecution(params).promise();
```
- **Función**: Inicia Step Functions workflow
- **Memoria**: 256 MB
- **Timeout**: 30s
- **Latencia**: <200ms

#### **5. Step Functions Workflow (1,500ms)**
```json
{
  "Comment": "Emergency Response Workflow - SLA <2 seconds",
  "StartAt": "RecordIncident",
  "States": {
    "RecordIncident": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:putItem",
      "Next": "DetermineResponseType"
    },
    "DetermineResponseType": {
      "Type": "Choice",
      "Choices": [{
        "Variable": "$.type",
        "StringEquals": "panic_button",
        "Next": "HighPriorityResponse"
      }]
    },
    "HighPriorityResponse": {
      "Type": "Parallel",
      "Branches": [
        {"StartAt": "NotifyAuthorities", "States": {...}},
        {"StartAt": "NotifyOwner", "States": {...}},
        {"StartAt": "ActivateVideoRecording", "States": {...}}
      ]
    }
  }
}
```

**Ejecución Paralela**:
- **Branch 1**: NotifyAuthorities → SNS → SMS/Email autoridades
- **Branch 2**: NotifyOwner → SNS → SMS/Email propietario  
- **Branch 3**: ActivateVideoRecording → Lambda → Activar cámara
- **Branch 4**: RecordIncident → DynamoDB → Log incidente

#### **6. Notificaciones SNS (1,800ms)**
```json
{
  "TopicArn": "arn:aws:sns:us-east-1:123456789012:ccs-dev-authorities-alerts",
  "Subject": "🚨 EMERGENCY ALERT - Immediate Response Required",
  "Message": {
    "default": "Emergency detected",
    "sms": "EMERGENCY: Vehicle VEH-001 - panic_button at location 4.6097,-74.0817",
    "email": "{\"incident_type\":\"panic_button\",\"vehicle_id\":\"VEH-001\",\"location\":{\"lat\":4.6097,\"lon\":-74.0817},\"severity\":\"CRITICAL\"}"
  }
}
```

#### **7. Finalización (2,000ms)**
- **DynamoDB**: Incidente registrado con status "notified"
- **SNS**: Notificaciones enviadas a autoridades y propietario
- **Lambda**: Cámara activada para grabación continua
- **CloudWatch**: Métricas y logs registrados

### **Métricas de Performance**
- **Latencia Total**: <2,000ms (p99)
- **Throughput**: 3,000 emergencias/segundo
- **Disponibilidad**: 99.9%
- **Costo**: $0.50/millón mensajes SQS + $0.025/millón requests Step Functions

---

## 📊 **FLUJO DE TELEMETRÍA NORMAL**

### **Descripción**
Procesamiento de datos de sensores (GPS, temperatura, velocidad) de 5,000+ vehículos con almacenamiento en tiempo real y análisis histórico.

### **Servicios Involucrados**
- **IoT Core** → **IoT Rules Engine** → **Kinesis Data Streams** → **Lambda Telemetry Processor** → **DynamoDB + Timestream**

### **Flujo Detallado**

#### **1. Envío de Telemetría (cada 30 segundos)**
```
Vehículo → Sensores → MQTT Publish
Topic: vehicle/{vehicleId}/telemetry
Payload: {
  "vehicleId": "VEH-001",
  "timestamp": 1698765432000,
  "location": {"lat": 4.6097, "lon": -74.0817},
  "speed": 65.5,
  "direction": 180.0,
  "cargo_temperature": 22.0,
  "engine_status": "on",
  "fuel_level": 75.5
}
```

#### **2. IoT Rules Engine (50ms)**
```sql
SELECT *, topic(2) as vehicleId, timestamp() as eventTimestamp 
FROM 'vehicle/+/telemetry'
```
- **Enrutamiento**: Kinesis Data Streams
- **Partition Key**: `${vehicleId}` (garantiza orden por vehículo)
- **Latencia**: <50ms

#### **3. Kinesis Data Streams (200ms)**
```json
{
  "StreamName": "ccs-dev-telemetry-stream",
  "ShardCount": 10,
  "RetentionPeriod": 24,
  "StreamMode": "PROVISIONED"
}
```
- **Shards**: 10 base, auto-scale a 50
- **Throughput**: 1,000 records/seg por shard
- **Retención**: 24 horas
- **Partition**: Por vehicleId para orden garantizado

#### **4. Lambda Telemetry Processor (500ms)**
```javascript
// telemetry_processor/index.js
for (const record of event.Records) {
    const payload = Buffer.from(record.kinesis.data, 'base64').toString('utf-8');
    const telemetry = JSON.parse(payload);
    
    // Store in DynamoDB (current state)
    await dynamodb.put({
        TableName: process.env.DYNAMODB_TELEMETRY_TABLE,
        Item: {
            vehicle_id: telemetry.vehicleId,
            timestamp: telemetry.timestamp,
            location: telemetry.location,
            speed: telemetry.speed,
            direction: telemetry.direction,
            cargo_temperature: telemetry.cargo_temperature,
            status: telemetry.speed > 0 ? 'moving' : 'stopped',
            ttl: Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60) // 90 days
        }
    }).promise();
    
    // Store in Timestream (time-series)
    await timestream.writeRecords({
        DatabaseName: process.env.TIMESTREAM_DATABASE,
        TableName: process.env.TIMESTREAM_TABLE,
        Records: [{
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
        }]
    }).promise();
}
```

**Configuración Lambda**:
- **Memoria**: 512 MB
- **Timeout**: 60s
- **Concurrencia**: 100 ejecuciones simultáneas
- **Batch Size**: 100 records por invocación
- **Window**: 60 segundos máximo

#### **5. Almacenamiento Dual**

**DynamoDB (Estado Actual)**:
```json
{
  "TableName": "ccs-dev-telemetry",
  "BillingMode": "PAY_PER_REQUEST",
  "KeySchema": [
    {"AttributeName": "vehicle_id", "KeyType": "HASH"},
    {"AttributeName": "timestamp", "KeyType": "RANGE"}
  ],
  "TTL": {
    "AttributeName": "ttl",
    "Enabled": true
  }
}
```

**Timestream (Series Temporales)**:
```json
{
  "DatabaseName": "ccs_dev_metrics",
  "TableName": "vehicle_metrics",
  "RetentionProperties": {
    "MemoryStoreRetentionPeriodInHours": 24,
    "MagneticStoreRetentionPeriodInDays": 365
  }
}
```

#### **6. DynamoDB Streams (600ms)**
```json
{
  "StreamEnabled": true,
  "StreamViewType": "NEW_AND_OLD_IMAGES"
}
```
- **Trigger**: Lambda para actualizaciones en tiempo real
- **Propósito**: Notificar cambios a WebSocket/AppSync
- **Latencia**: <100ms adicional

### **Métricas de Performance**
- **Throughput**: 5,000 msg/seg (10 shards × 500 msg/seg)
- **Latencia**: <500ms (p95)
- **Disponibilidad**: 99.9%
- **Costo**: $0.015/shard-hora + $0.014/millón records DynamoDB

---

## 🔍 **FLUJO DE DETECCIÓN DE ANOMALÍAS**

### **Descripción**
Análisis en tiempo real de patrones anómalos en telemetría con escalación automática a emergencias cuando se detectan comportamientos críticos.

### **Servicios Involucrados**
- **Lambda Telemetry Processor** → **Lambda Anomaly Detector** → **SQS FIFO** (si crítico)

### **Flujo Detallado**

#### **1. Trigger desde Telemetría**
```javascript
// Desde telemetry_processor/index.js
// Después de procesar telemetría normal
if (shouldCheckAnomalies(telemetry)) {
    await lambda.invoke({
        FunctionName: 'ccs-dev-anomaly-detector',
        InvocationType: 'Event', // Async
        Payload: JSON.stringify(telemetry)
    }).promise();
}
```

#### **2. Lambda Anomaly Detector**
```javascript
// anomaly_detector/index.js
exports.handler = async (event) => {
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
        vehicleId: telemetry.vehicleId,
        anomalies: anomalies,
        escalated: criticalAnomalies.length > 0
    };
};
```

#### **3. Reglas de Detección**

**Velocidad Excesiva**:
- **Condición**: `speed > 120 km/h`
- **Severidad**: High
- **Acción**: Escalar a emergencia

**Temperatura Alta**:
- **Condición**: `cargo_temperature > 30°C`
- **Severidad**: Medium
- **Acción**: Notificar propietario

**Motor Encendido en Reposo**:
- **Condición**: `speed = 0 AND engine_status = 'on'`
- **Severidad**: Low
- **Acción**: Log para análisis

**Desvío de Ruta**:
- **Condición**: `distance_from_route > 5km`
- **Severidad**: High
- **Acción**: Escalar a emergencia

#### **4. Escalación a Emergencia**
```json
{
  "QueueUrl": "https://sqs.us-east-1.amazonaws.com/123456789012/ccs-dev-emergency-queue.fifo",
  "MessageBody": "{\"vehicleId\":\"VEH-001\",\"type\":\"critical_anomaly\",\"severity\":\"critical\",\"anomalies\":[{\"type\":\"excessive_speed\",\"severity\":\"high\",\"value\":135,\"threshold\":120}],\"location\":{\"lat\":4.6097,\"lon\":-74.0817},\"timestamp\":1698765432000}",
  "MessageGroupId": "VEH-001",
  "MessageDeduplicationId": "VEH-001-1698765432000"
}
```

### **Métricas de Performance**
- **Latencia**: <100ms (detección)
- **Precisión**: 95% (reglas simples)
- **Escalación**: <500ms (a emergencia)
- **Costo**: $0.20/millón invocaciones Lambda

---

## 🌐 **FLUJO DE ACTUALIZACIONES EN TIEMPO REAL**

### **Descripción**
Propagación de cambios de telemetría a clientes conectados via WebSocket y GraphQL subscriptions en tiempo real.

### **Servicios Involucrados**
- **DynamoDB Streams** → **Lambda Stream Handler** → **WebSocket API** + **AppSync**

### **Flujo Detallado**

#### **1. DynamoDB Streams Trigger**
```json
{
  "Records": [{
    "eventName": "INSERT",
    "dynamodb": {
      "NewImage": {
        "vehicle_id": {"S": "VEH-001"},
        "timestamp": {"N": "1698765432000"},
        "location": {"M": {"lat": {"N": "4.6097"}, "lon": {"N": "-74.0817"}}},
        "speed": {"N": "65.5"},
        "status": {"S": "moving"}
      }
    }
  }]
}
```

#### **2. Lambda Stream Handler**
```javascript
// stream_handler/index.js (implícito en websocket_handler)
exports.handler = async (event) => {
    for (const record of event.Records) {
        if (record.eventName === 'INSERT' || record.eventName === 'MODIFY') {
            const vehicleId = record.dynamodb.NewImage.vehicle_id.S;
            const data = unmarshall(record.dynamodb.NewImage);
            
            // Update cache
            await elasticache.setex(`vehicle:${vehicleId}`, 30, JSON.stringify(data));
            
            // Broadcast to WebSocket clients
            await broadcastToWebSocket(vehicleId, data);
            
            // Trigger AppSync subscription
            await triggerAppSyncSubscription(vehicleId, data);
        }
    }
};
```

#### **3. WebSocket Broadcast**
```javascript
// websocket_handler/index.js
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
```

#### **4. AppSync Subscription**
```graphql
# Schema GraphQL
type Subscription {
  onVehicleUpdate(vehicleId: ID!): Vehicle
    @aws_subscribe(mutations: ["updateVehicle"])
}

# Resolver mutation
type Mutation {
  updateVehicle(vehicleId: ID!, location: LocationInput, speed: Float): Vehicle
}
```

#### **5. Cliente Recibe Actualización**
```javascript
// Frontend JavaScript
const subscription = API.graphql({
  query: `
    subscription OnVehicleUpdate($vehicleId: ID!) {
      onVehicleUpdate(vehicleId: $vehicleId) {
        vehicleId
        timestamp
        location { lat lon }
        speed
        status
      }
    }
  `,
  variables: { vehicleId: 'VEH-001' }
}).subscribe({
  next: (data) => {
    console.log('Vehicle updated:', data.value.data.onVehicleUpdate);
    updateMapMarker(data.value.data.onVehicleUpdate);
  }
});
```

### **Métricas de Performance**
- **Latencia**: <200ms (DynamoDB → Cliente)
- **Concurrencia**: 10,000+ conexiones WebSocket
- **Throughput**: 1,000 updates/seg
- **Costo**: $0.25/connection-hora + $1.00/millón mensajes

---

## 💾 **FLUJO DE DATA LAKE (ANALYTICS)**

### **Descripción**
Procesamiento de datos históricos para análisis, reportes y business intelligence con almacenamiento optimizado en S3.

### **Servicios Involucrados**
- **Kinesis Data Streams** → **Kinesis Firehose** → **S3** → **Glue Crawler** → **Athena/QuickSight**

### **Flujo Detallado**

#### **1. Fan-out desde Kinesis**
```json
{
  "StreamName": "ccs-dev-telemetry-stream",
  "FirehoseDeliveryStream": "ccs-dev-data-lake-firehose"
}
```
- **Propósito**: Duplicar datos para analytics
- **Latencia**: <1s
- **Retención**: Sin límite

#### **2. Kinesis Firehose**
```json
{
  "DeliveryStreamName": "ccs-dev-data-lake-firehose",
  "Destination": "extended_s3",
  "ExtendedS3Configuration": {
    "BucketARN": "arn:aws:s3:::ccs-dev-data-lake",
    "Prefix": "telemetry/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/",
    "ErrorOutputPrefix": "errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/",
    "BufferingSize": 128,
    "BufferingInterval": 300,
    "CompressionFormat": "UNCOMPRESSED",
    "DataFormatConversionConfiguration": {
      "InputFormatConfiguration": {
        "Deserializer": {
          "OpenXJsonSerDe": {}
        }
      },
      "OutputFormatConfiguration": {
        "Serializer": {
          "ParquetSerDe": {}
        }
      },
      "SchemaConfiguration": {
        "DatabaseName": "ccs_dev_telemetry_db",
        "TableName": "telemetry",
        "RoleARN": "arn:aws:iam::123456789012:role/ccs-dev-firehose-role"
      }
    }
  }
}
```

#### **3. Almacenamiento S3**
```
s3://ccs-dev-data-lake/
├── telemetry/
│   ├── year=2024/
│   │   ├── month=01/
│   │   │   ├── day=15/
│   │   │   │   ├── 20240115-000000-000000.parquet
│   │   │   │   ├── 20240115-000500-000000.parquet
│   │   │   │   └── ...
│   │   │   └── day=16/
│   │   └── month=02/
│   └── year=2023/
└── errors/
    └── firehose-errors/
```

**Características**:
- **Formato**: Parquet (70% compresión vs JSON)
- **Partición**: Por año/mes/día para queries eficientes
- **Lifecycle**: Intelligent Tiering → Glacier → Expiración

#### **4. AWS Glue Crawler**
```json
{
  "CrawlerName": "ccs-dev-telemetry-crawler",
  "Role": "arn:aws:iam::123456789012:role/ccs-dev-glue-role",
  "DatabaseName": "ccs_dev_telemetry_db",
  "Targets": {
    "S3Targets": [{
      "Path": "s3://ccs-dev-data-lake/telemetry/"
    }]
  },
  "Schedule": "cron(0 2 * * ? *)"
}
```

**Schema Discovery**:
```sql
CREATE TABLE telemetry (
  vehicle_id string,
  timestamp bigint,
  location struct<lat:double,lon:double>,
  speed double,
  direction double,
  cargo_temperature double,
  engine_status string,
  fuel_level double
)
PARTITIONED BY (
  year string,
  month string,
  day string
)
STORED AS PARQUET
LOCATION 's3://ccs-dev-data-lake/telemetry/'
```

#### **5. Amazon Athena Queries**
```sql
-- Query 1: Velocidad promedio por vehículo
SELECT 
  vehicle_id,
  AVG(speed) as avg_speed,
  COUNT(*) as records_count
FROM telemetry
WHERE year = '2024' AND month = '01'
GROUP BY vehicle_id
ORDER BY avg_speed DESC;

-- Query 2: Vehículos con temperatura alta
SELECT 
  vehicle_id,
  MAX(cargo_temperature) as max_temp,
  COUNT(*) as high_temp_events
FROM telemetry
WHERE year = '2024' 
  AND cargo_temperature > 30
GROUP BY vehicle_id
HAVING COUNT(*) > 10;

-- Query 3: Patrones de uso por hora
SELECT 
  HOUR(FROM_UNIXTIME(timestamp/1000)) as hour,
  COUNT(*) as activity_count,
  AVG(speed) as avg_speed
FROM telemetry
WHERE year = '2024' AND month = '01'
GROUP BY HOUR(FROM_UNIXTIME(timestamp/1000))
ORDER BY hour;
```

#### **6. QuickSight Dashboards**
```json
{
  "DataSource": {
    "Type": "ATHENA",
    "DataSourceParameters": {
      "Catalog": "AwsDataCatalog",
      "Database": "ccs_dev_telemetry_db",
      "Table": "telemetry"
    }
  },
  "Visualizations": [
    {
      "Type": "LINE_CHART",
      "Title": "Vehicle Speed Over Time",
      "XAxis": "timestamp",
      "YAxis": "speed",
      "GroupBy": "vehicle_id"
    },
    {
      "Type": "HEAT_MAP",
      "Title": "Temperature Distribution",
      "XAxis": "vehicle_id",
      "YAxis": "cargo_temperature",
      "Color": "COUNT(*)"
    }
  ]
}
```

### **Métricas de Performance**
- **Latencia**: 5 min (buffer Firehose)
- **Compresión**: 70% (Parquet vs JSON)
- **Query Performance**: <10s (Athena)
- **Costo**: $0.029/GB procesado + $5.00/TB queryado

---

## 🛒 **FLUJO DE PROCESO DE VENTAS**

### **Descripción**
Automatización completa del proceso de ventas desde solicitud hasta activación del servicio, con aprobaciones automáticas y manuales.

### **Servicios Involucrados**
- **API Gateway** → **ECS Sales Service** → **Step Functions** → **Stripe** → **Government API** → **SNS**

### **Flujo Detallado**

#### **1. Solicitud de Cliente**
```json
POST /api/sales/contracts
{
  "customer_id": "CUST-001",
  "company_name": "Transportes ABC",
  "document_type": "NIT",
  "document_id": "900123456-7",
  "number_of_vehicles": 75,
  "contract_type": "premium",
  "estimated_value": 15000,
  "payment_method": "credit_card"
}
```

#### **2. ECS Sales Service**
```javascript
// sales_service/server.js
app.post('/api/sales/contracts', async (req, res) => {
    const contractData = req.body;
    
    // Validate customer data
    const validation = await validateCustomer(contractData);
    if (!validation.valid) {
        return res.status(400).json({ error: validation.error });
    }
    
    // Start business workflow
    const workflowInput = {
        customer_id: contractData.customer_id,
        document_type: contractData.document_type,
        document_id: contractData.document_id,
        company_info: contractData.company_name,
        number_of_vehicles: contractData.number_of_vehicles,
        contract_type: contractData.contract_type,
        estimated_value: contractData.estimated_value,
        payment_method: contractData.payment_method,
        execution_id: generateExecutionId()
    };
    
    const result = await stepfunctions.startExecution({
        stateMachineArn: process.env.BUSINESS_WORKFLOW_ARN,
        input: JSON.stringify(workflowInput)
    }).promise();
    
    res.json({
        contract_id: generateContractId(),
        workflow_execution: result.executionArn,
        status: 'processing'
    });
});
```

#### **3. Step Functions Business Workflow**
```json
{
  "Comment": "Business Process Workflow - Sales and Approvals",
  "StartAt": "ValidateCustomerData",
  "States": {
    "ValidateCustomerData": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "ccs-dev-validation-lambda",
        "Payload": {
          "customer_id": "$.customer_id",
          "document_type": "$.document_type",
          "document_id": "$.document_id",
          "company_info": "$.company_info"
        }
      },
      "Next": "CheckValidationStatus"
    },
    "CheckValidationStatus": {
      "Type": "Choice",
      "Choices": [{
        "Variable": "$.validationResult.Payload.valid",
        "BooleanEquals": true,
        "Next": "CheckContractSize"
      }],
      "Default": "ValidationFailed"
    },
    "CheckContractSize": {
      "Type": "Choice",
      "Choices": [{
        "Variable": "$.number_of_vehicles",
        "NumericLessThan": 50,
        "Next": "AutoApprove"
      }],
      "Default": "RequireManagerApproval"
    },
    "AutoApprove": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "ccs-dev-contract-creation-lambda",
        "Payload": {
          "customer_id": "$.customer_id",
          "number_of_vehicles": "$.number_of_vehicles",
          "contract_type": "$.contract_type",
          "approval_type": "automatic",
          "approved_by": "system"
        }
      },
      "Next": "ProcessPayment"
    },
    "RequireManagerApproval": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sns:publish",
      "Parameters": {
        "TopicArn": "arn:aws:sns:us-east-1:123456789012:ccs-dev-manager-notifications",
        "Subject": "Manager Approval Required - Large Contract",
        "Message": {
          "default": "Manager approval required",
          "email": "{\"customer_id\":\"$.customer_id\",\"number_of_vehicles\":\"$.number_of_vehicles\",\"estimated_value\":\"$.estimated_value\",\"approval_token\":\"$.execution_id\"}"
        }
      },
      "Next": "WaitForApproval"
    },
    "WaitForApproval": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke.waitForTaskToken",
      "Parameters": {
        "FunctionName": "ccs-dev-approval-handler-lambda",
        "Payload": {
          "task_token.$": "$$.Task.Token",
          "execution_id": "$.execution_id",
          "customer_id": "$.customer_id",
          "timeout": 86400
        }
      },
      "TimeoutSeconds": 86400,
      "Next": "CheckApprovalDecision"
    },
    "ProcessPayment": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "ccs-dev-payment-processing-lambda",
        "Payload": {
          "customer_id": "$.customer_id",
          "contract_id": "$.contractResult.Payload.contract_id",
          "amount": "$.estimated_value",
          "payment_method": "$.payment_method"
        }
      },
      "Next": "ActivateService"
    },
    "ActivateService": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "ccs-dev-service-activation-lambda",
        "Payload": {
          "customer_id": "$.customer_id",
          "contract_id": "$.contractResult.Payload.contract_id",
          "vehicles": "$.vehicles"
        }
      },
      "End": true
    }
  }
}
```

#### **4. Validación de Cliente**
```javascript
// validation_lambda/index.js
exports.handler = async (event) => {
    const { document_type, document_id, company_info } = event;
    
    // Validate with government API
    const govResponse = await fetch('https://api.gov.co/validate-company', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${process.env.GOV_API_KEY}` },
        body: JSON.stringify({
            document_type,
            document_id,
            company_name: company_info
        })
    });
    
    const govData = await govResponse.json();
    
    return {
        valid: govData.status === 'active',
        company_data: govData.company_info,
        validation_date: new Date().toISOString()
    };
};
```

#### **5. Procesamiento de Pago**
```javascript
// payment_processing_lambda/index.js
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

exports.handler = async (event) => {
    const { customer_id, contract_id, amount, payment_method } = event;
    
    try {
        // Create Stripe payment intent
        const paymentIntent = await stripe.paymentIntents.create({
            amount: amount * 100, // Convert to cents
            currency: 'usd',
            customer: customer_id,
            payment_method: payment_method,
            confirmation_method: 'manual',
            confirm: true
        });
        
        if (paymentIntent.status === 'succeeded') {
            // Store payment record in Aurora
            await aurora.query(
                'INSERT INTO payments (contract_id, amount, stripe_payment_id, status) VALUES (?, ?, ?, ?)',
                [contract_id, amount, paymentIntent.id, 'completed']
            );
            
            return {
                status: 'success',
                payment_id: paymentIntent.id,
                amount: amount
            };
        } else {
            throw new Error('Payment failed');
        }
    } catch (error) {
        return {
            status: 'failed',
            error: error.message
        };
    }
};
```

#### **6. Activación del Servicio**
```javascript
// service_activation_lambda/index.js
exports.handler = async (event) => {
    const { customer_id, contract_id, vehicles } = event;
    
    // Create IoT Things for vehicles
    for (const vehicle of vehicles) {
        await iot.createThing({
            thingName: vehicle.vehicle_id,
            thingTypeName: 'ccs-dev-vehicle-thing-type',
            attributes: {
                customer_id: customer_id,
                contract_id: contract_id,
                vehicle_model: vehicle.model,
                region: 'us-east-1'
            }
        }).promise();
        
        // Generate certificates
        const cert = await iot.createKeysAndCertificate({
            setAsActive: true
        }).promise();
        
        // Attach policy
        await iot.attachPolicy({
            policyName: 'ccs-dev-vehicle-policy',
            target: cert.certificateArn
        }).promise();
        
        // Attach certificate to thing
        await iot.attachThingPrincipal({
            thingName: vehicle.vehicle_id,
            principal: cert.certificateArn
        }).promise();
    }
    
    // Update contract status
    await aurora.query(
        'UPDATE contracts SET status = ?, activated_at = ? WHERE contract_id = ?',
        ['active', new Date(), contract_id]
    );
    
    // Send welcome email
    await sns.publish({
        TopicArn: 'arn:aws:sns:us-east-1:123456789012:ccs-dev-owner-alerts',
        Subject: 'Welcome to CCS - Service Activated',
        Message: JSON.stringify({
            customer_id: customer_id,
            contract_id: contract_id,
            message: 'Welcome to CCS! Your vehicle monitoring service is now active.'
        })
    }).promise();
    
    return {
        status: 'activated',
        vehicles_configured: vehicles.length,
        contract_id: contract_id
    };
};
```

### **Métricas de Performance**
- **Tiempo Auto-aprobación**: <5 minutos
- **Tiempo Aprobación Manual**: <24 horas
- **Tasa de Éxito**: 95%
- **Costo**: $0.025/millón requests Step Functions

---

## 🔐 **FLUJO DE AUTENTICACIÓN**

### **Descripción**
Autenticación y autorización de usuarios con Cognito User Pools, JWT tokens y roles RBAC.

### **Servicios Involucrados**
- **Cognito User Pool** → **API Gateway** → **Lambda Authorizer** → **IAM Roles**

### **Flujo Detallado**

#### **1. Login de Usuario**
```javascript
// Frontend
const authResult = await Auth.signIn(username, password);
const { idToken, accessToken, refreshToken } = authResult;
```

#### **2. Cognito User Pool**
```json
{
  "UserPoolId": "us-east-1_ABC123DEF",
  "ClientId": "1234567890abcdef",
  "UserPoolName": "ccs-dev-user-pool",
  "Policies": {
    "PasswordPolicy": {
      "MinimumLength": 12,
      "RequireUppercase": true,
      "RequireLowercase": true,
      "RequireNumbers": true,
      "RequireSymbols": true
    }
  },
  "MfaConfiguration": "OPTIONAL",
  "MfaTypes": ["TOTP"]
}
```

#### **3. Grupos RBAC**
```json
{
  "Groups": [
    {
      "GroupName": "Administrators",
      "Precedence": 1,
      "Description": "Full system access"
    },
    {
      "GroupName": "Viewers", 
      "Precedence": 2,
      "Description": "Read-only access"
    },
    {
      "GroupName": "Purchasers",
      "Precedence": 3,
      "Description": "Can create contracts"
    },
    {
      "GroupName": "Approvers",
      "Precedence": 4,
      "Description": "Can approve contracts"
    },
    {
      "GroupName": "Managers",
      "Precedence": 0,
      "Description": "Management access"
    }
  ]
}
```

#### **4. JWT Token**
```json
{
  "header": {
    "alg": "RS256",
    "kid": "ABC123DEF456",
    "typ": "JWT"
  },
  "payload": {
    "sub": "12345678-1234-1234-1234-123456789012",
    "aud": "1234567890abcdef",
    "iss": "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_ABC123DEF",
    "token_use": "id",
    "auth_time": 1698765432,
    "exp": 1698769032,
    "iat": 1698765432,
    "cognito:groups": ["Administrators"],
    "email": "admin@ccs.co",
    "email_verified": true,
    "cognito:username": "admin"
  }
}
```

#### **5. API Gateway Authorization**
```javascript
// API Gateway Cognito Authorizer
{
  "Type": "COGNITO_USER_POOLS",
  "ProviderARNs": ["arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_ABC123DEF"],
  "IdentitySource": "method.request.header.Authorization"
}
```

#### **6. Verificación en Lambda**
```javascript
// Lambda function
exports.handler = async (event) => {
    const token = event.headers.Authorization.replace('Bearer ', '');
    
    try {
        const decoded = jwt.verify(token, publicKey);
        
        // Check user groups
        const userGroups = decoded['cognito:groups'] || [];
        
        if (userGroups.includes('Administrators')) {
            // Full access
            return await processRequest(event);
        } else if (userGroups.includes('Viewers')) {
            // Read-only access
            if (event.httpMethod !== 'GET') {
                throw new Error('Unauthorized');
            }
            return await processRequest(event);
        } else {
            throw new Error('Insufficient permissions');
        }
    } catch (error) {
        return {
            statusCode: 401,
            body: JSON.stringify({ error: 'Unauthorized' })
        };
    }
};
```

### **Métricas de Performance**
- **Latencia**: <100ms (token validation)
- **Disponibilidad**: 99.9%
- **Costo**: $0.0055/Monthly Active User

---

## 📱 **FLUJO DE API REST**

### **Descripción**
API REST para operaciones CRUD de vehículos con autenticación Cognito y rate limiting.

### **Servicios Involucrados**
- **CloudFront** → **API Gateway** → **ALB** → **ECS Monitoring Service** → **DynamoDB + Redis**

### **Flujo Detallado**

#### **1. Request del Cliente**
```bash
curl -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
     https://api.ccs.co/dev/vehicles/VEH-001
```

#### **2. CloudFront Distribution**
```json
{
  "DistributionId": "E1234567890ABC",
  "DomainName": "d1234567890abc.cloudfront.net",
  "Origins": [
    {
      "DomainName": "api.ccs.co",
      "OriginPath": "/dev",
      "CustomOriginConfig": {
        "HTTPPort": 443,
        "HTTPSPort": 443,
        "OriginProtocolPolicy": "https-only"
      }
    }
  ],
  "DefaultCacheBehavior": {
    "TargetOriginId": "api-origin",
    "ViewerProtocolPolicy": "redirect-to-https",
    "CachePolicyId": "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  }
}
```

#### **3. API Gateway**
```json
{
  "RestApiId": "abc123def4",
  "Name": "ccs-dev-rest-api",
  "Description": "CCS REST API for vehicle monitoring",
  "EndpointConfiguration": {
    "Types": ["REGIONAL"]
  },
  "Resources": {
    "/vehicles": {
      "/{vehicleId}": {
        "GET": {
          "AuthorizationType": "COGNITO_USER_POOLS",
          "AuthorizerId": "abc123def4",
          "Integration": {
            "Type": "HTTP_PROXY",
            "IntegrationHttpMethod": "GET",
            "Uri": "http://ccs-dev-alb-v2-123456789.us-east-1.elb.amazonaws.com/api/vehicles/{vehicleId}"
          }
        }
      }
    }
  }
}
```

#### **4. Application Load Balancer**
```json
{
  "LoadBalancerArn": "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/ccs-dev-alb-v2/1234567890abcdef",
  "DNSName": "ccs-dev-alb-v2-123456789.us-east-1.elb.amazonaws.com",
  "Scheme": "internet-facing",
  "Type": "application",
  "SecurityGroups": ["sg-12345678"],
  "Subnets": ["subnet-12345678", "subnet-87654321", "subnet-11223344"]
}
```

#### **5. ECS Monitoring Service**
```javascript
// monitoring_service/server.js
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
```

#### **6. DynamoDB Query**
```json
{
  "TableName": "ccs-dev-telemetry",
  "KeyConditionExpression": "vehicle_id = :vid",
  "ExpressionAttributeValues": {
    ":vid": "VEH-001"
  },
  "Limit": 1,
  "ScanIndexForward": false
}
```

#### **7. Response Chain**
```json
{
  "vehicle_id": "VEH-001",
  "timestamp": 1698765432000,
  "location": {
    "lat": 4.6097,
    "lon": -74.0817
  },
  "speed": 65.5,
  "direction": 180.0,
  "cargo_temperature": 22.0,
  "status": "moving"
}
```

### **Métricas de Performance**
- **Latencia**: <200ms (p95)
- **Throughput**: 1,000 req/seg
- **Cache Hit Rate**: >90%
- **Costo**: $3.50/millón requests API Gateway

---

## 🔌 **FLUJO DE WEBSOCKET**

### **Descripción**
Conexiones WebSocket persistentes para actualizaciones en tiempo real de vehículos.

### **Servicios Involucrados**
- **API Gateway WebSocket** → **Lambda WebSocket Handler** → **DynamoDB Connections**

### **Flujo Detallado**

#### **1. Conexión del Cliente**
```javascript
// Frontend
const ws = new WebSocket('wss://abc123def4.execute-api.us-east-1.amazonaws.com/dev?token=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...');

ws.onopen = () => {
    console.log('Connected to WebSocket');
    
    // Subscribe to specific vehicles
    ws.send(JSON.stringify({
        action: 'subscribe',
        vehicleIds: ['VEH-001', 'VEH-002', 'VEH-003']
    }));
};
```

#### **2. API Gateway WebSocket**
```json
{
  "ApiId": "abc123def4",
  "Name": "ccs-dev-websocket-api",
  "ProtocolType": "WEBSOCKET",
  "RouteSelectionExpression": "$request.body.action",
  "Routes": {
    "$connect": {
      "Target": "integrations/connect-integration"
    },
    "$disconnect": {
      "Target": "integrations/disconnect-integration"
    },
    "subscribe": {
      "Target": "integrations/subscribe-integration"
    },
    "ping": {
      "Target": "integrations/ping-integration"
    }
  }
}
```

#### **3. Lambda WebSocket Handler**
```javascript
// websocket_handler/index.js
exports.handler = async (event) => {
    const { routeKey, connectionId } = event.requestContext;
    
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
};

async function handleConnect(connectionId, event) {
    const item = {
        connection_id: connectionId,
        connected_at: Date.now(),
        ttl: Math.floor(Date.now() / 1000) + (24 * 60 * 60) // 24 hours
    };
    
    // Extract user info from query parameters
    if (event.queryStringParameters && event.queryStringParameters.userId) {
        item.user_id = event.queryStringParameters.userId;
    }
    
    await dynamodb.put({
        TableName: process.env.CONNECTIONS_TABLE,
        Item: item
    }).promise();
    
    return { statusCode: 200, body: 'Connected' };
}

async function handleSubscribe(connectionId, event) {
    const body = JSON.parse(event.body);
    const { vehicleIds } = body;
    
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
```

#### **4. DynamoDB Connections Table**
```json
{
  "TableName": "ccs-dev-websocket-connections",
  "KeySchema": [
    {
      "AttributeName": "connection_id",
      "KeyType": "HASH"
    }
  ],
  "AttributeDefinitions": [
    {
      "AttributeName": "connection_id",
      "AttributeType": "S"
    }
  ],
  "BillingMode": "PAY_PER_REQUEST",
  "TTL": {
    "AttributeName": "ttl",
    "Enabled": true
  }
}
```

#### **5. Broadcast de Actualizaciones**
```javascript
// Cuando DynamoDB Streams detecta cambio en telemetría
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
```

#### **6. Cliente Recibe Actualización**
```javascript
// Frontend
ws.onmessage = (event) => {
    const message = JSON.parse(event.data);
    
    if (message.type === 'vehicle_update') {
        console.log('Vehicle updated:', message.vehicleId);
        updateMapMarker(message.data);
        updateDashboard(message.data);
    }
};
```

### **Métricas de Performance**
- **Conexiones Concurrentes**: 10,000+
- **Latencia**: <100ms (broadcast)
- **Throughput**: 1,000 updates/seg
- **Costo**: $0.25/connection-hora + $1.00/millón mensajes

---

## 📈 **FLUJO DE GRAPHQL**

### **Descripción**
API GraphQL con subscriptions en tiempo real para consultas flexibles y actualizaciones push.

### **Servicios Involucrados**
- **AppSync** → **DynamoDB** → **Lambda Resolvers**

### **Flujo Detallado**

#### **1. Schema GraphQL**
```graphql
type Vehicle {
  vehicleId: ID!
  timestamp: AWSTimestamp!
  location: Location
  speed: Float
  direction: Float
  cargoTemperature: Float
  status: String
}

type Location {
  lat: Float!
  lon: Float!
}

type Query {
  getVehicle(vehicleId: ID!): Vehicle
  listVehicles(limit: Int): [Vehicle]
}

type Mutation {
  updateVehicle(vehicleId: ID!, location: LocationInput, speed: Float): Vehicle
}

input LocationInput {
  lat: Float!
  lon: Float!
}

type Subscription {
  onVehicleUpdate(vehicleId: ID!): Vehicle
    @aws_subscribe(mutations: ["updateVehicle"])
}
```

#### **2. Query del Cliente**
```javascript
// Frontend
const query = `
  query GetVehicle($vehicleId: ID!) {
    getVehicle(vehicleId: $vehicleId) {
      vehicleId
      timestamp
      location { lat lon }
      speed
      status
    }
  }
`;

const result = await API.graphql({
  query: query,
  variables: { vehicleId: 'VEH-001' }
});
```

#### **3. AppSync Resolver**
```javascript
// Request Template
{
  "version": "2017-02-28",
  "operation": "Query",
  "query": {
    "expression": "vehicle_id = :vehicleId",
    "expressionValues": {
      ":vehicleId": $util.dynamodb.toDynamoDBJson($ctx.args.vehicleId)
    }
  },
  "scanIndexForward": false,
  "limit": 1
}

// Response Template
#if($ctx.result.items.size() > 0)
  $util.toJson($ctx.result.items[0])
#else
  null
#end
```

#### **4. Subscription del Cliente**
```javascript
// Frontend
const subscription = API.graphql({
  query: `
    subscription OnVehicleUpdate($vehicleId: ID!) {
      onVehicleUpdate(vehicleId: $vehicleId) {
        vehicleId
        timestamp
        location { lat lon }
        speed
        status
      }
    }
  `,
  variables: { vehicleId: 'VEH-001' }
}).subscribe({
  next: (data) => {
    console.log('Vehicle updated:', data.value.data.onVehicleUpdate);
    updateMapMarker(data.value.data.onVehicleUpdate);
  },
  error: (error) => {
    console.error('Subscription error:', error);
  }
});
```

#### **5. Trigger de Subscription**
```javascript
// Cuando DynamoDB Streams detecta cambio
async function triggerAppSyncSubscription(vehicleId, data) {
    const mutation = `
      mutation UpdateVehicle($vehicleId: ID!, $location: LocationInput, $speed: Float) {
        updateVehicle(vehicleId: $vehicleId, location: $location, speed: $speed) {
          vehicleId
          timestamp
          location { lat lon }
          speed
          status
        }
      }
    `;
    
    await API.graphql({
      query: mutation,
      variables: {
        vehicleId: vehicleId,
        location: data.location,
        speed: data.speed
      }
    });
}
```

### **Métricas de Performance**
- **Latencia**: <100ms (queries)
- **Subscriptions**: <200ms (updates)
- **Throughput**: 1,000 queries/seg
- **Costo**: $4.00/millón requests + $2.00/millón mutations

---

## 📊 **RESUMEN DE FLUJOS**

| Flujo | Latencia | Throughput | Servicios | Costo/mes |
|-------|----------|------------|-----------|-----------|
| **Emergencia** | <2s | 3K/seg | 8 servicios | $150 |
| **Telemetría** | <500ms | 5K/seg | 6 servicios | $300 |
| **Anomalías** | <100ms | 1K/seg | 3 servicios | $50 |
| **Tiempo Real** | <200ms | 1K/seg | 4 servicios | $200 |
| **Data Lake** | 5 min | 5K/seg | 5 servicios | $100 |
| **Ventas** | <5 min | 100/seg | 7 servicios | $75 |
| **Auth** | <100ms | 1K/seg | 3 servicios | $25 |
| **API REST** | <200ms | 1K/seg | 6 servicios | $200 |
| **WebSocket** | <100ms | 1K/seg | 3 servicios | $150 |
| **GraphQL** | <100ms | 1K/seg | 3 servicios | $100 |

**Total Sistema**: **$1,350/mes** para procesamiento completo de 5,000+ vehículos.

---

**Este documento te da una comprensión completa de todos los flujos del sistema CCS. Cada flujo está optimizado para su caso de uso específico con métricas de performance y costos detallados.** 🚀
