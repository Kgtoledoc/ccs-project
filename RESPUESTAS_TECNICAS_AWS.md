# 🎯 Respuestas Técnicas para Preguntas Sobre AWS - Presentación CCS

**Documento de Referencia Rápida** para responder preguntas técnicas sobre los servicios AWS implementados.

---

## 🌐 **NETWORKING & SECURITY**

### **VPC (Virtual Private Cloud)**
**¿Por qué una VPC multi-AZ con 3 subnets públicas, privadas y database?**

✅ **Respuesta**:  
"Implementamos VPC con arquitectura de 3 capas en 3 Availability Zones para alta disponibilidad. Las subnets públicas alojan ALB y NAT Gateways, las privadas contienen ECS/Lambda sin acceso directo a internet, y las database alojan RDS/ElastiCache con doble aislamiento. Esto sigue el principio de **defense in depth** - cada falla de firewall afecta solo una capa."

**Números clave**: 
- 3 AZs (us-east-1a/b/c)
- CIDR 10.0.0.0/16 con subnets /24
- NAT Gateways redundantes ($32/each/mes)

---

### **Security Groups**
**¿Cómo garantizas que solo el tráfico legítimo accede a los recursos?**

✅ **Respuesta**:  
"Configuramos 6 Security Groups con reglas de **least privilege**. Por ejemplo: Database SG solo acepta PostgreSQL (5432) desde ECS y Lambda, ALB solo 80/443 desde internet, ECS solo recibe desde ALB. No hay reglas 0.0.0.0/0 en inbound, eliminando vectores de ataque desde internet."

**Configuración**:
- ALB SG: Ingress 80/443 desde 0.0.0.0/0 (solo HTTPs público)
- ECS SG: Solo desde ALB SG
- Database SG: Solo 5432 desde ECS/Lambda
- Cache SG: Solo 6379 desde ECS/Lambda

---

### **VPC Endpoints**
**¿Por qué VPC Endpoints si ya tienes NAT Gateways?**

✅ **Respuesta**:  
"Los VPC Endpoints evitan recorrer NAT Gateways para servicios AWS (S3, DynamoDB, CloudWatch). Beneficios: **$29/mes** vs NAT data transfer, **menor latencia** (ruta directa a AWS), **seguridad mejorada** (tráfico no sale de backbone AWS). Para CloudWatch Logs y ECR críticos, endpoints son casi obligatorios."

**Endpoints configurados**:
- S3 Gateway (gratis)
- DynamoDB Gateway (gratis)
- ECR API/API DKR Interface (ECR para Docker)
- CloudWatch Logs Interface
- Secrets Manager Interface

---

## 📡 **IoT CORE**

### **AWS IoT Core**
**¿Por qué elegir IoT Core vs API Gateway REST para dispositivos?**

✅ **Respuesta**:  
"IoT Core es **especializado** para IoT con MQTT over TLS, 500K conexiones concurrentes, y integración nativa con Rules Engine. A diferencia de REST API, soporta QoS 1 (guaranteed delivery), Device Shadow (estado sincronizado), y certificados X.509 por dispositivo. Costo: **$1.00/millon de mensajes** vs $3.50/millón en API Gateway."

**Características**:
- MQTT pub/sub para telemetría
- Thing Registry para device management
- Device Shadow para sincronización estado
- Rules Engine para routing inteligente (SQL-like)

---

### **IoT Rules Engine**
**¿Cómo funciona el enrutamiento de eventos a diferentes lanes?**

✅ **Respuesta**:  
"Reglas SQL evalúan mensajes entrantes y enrutan según prioridad. Por ejemplo: `SELECT * FROM 'vehicle/+/emergency' WHERE type IN ('panic_button', 'accident')` → SQS FIFO para <2s processing. Rules separadas para telemetría → Kinesis, video metadata → DynamoDB. Esto **desacopla** dispositivos del procesamiento downstream."

**Ejemplo de rule**:
```sql
SELECT *, topic(2) as vehicleId, timestamp() as eventTimestamp 
FROM 'vehicle/+/telemetry' 
WHERE cargo_temperature > 30
```

---

## 🔄 **STREAMING**

### **Amazon Kinesis Data Streams**
**¿Por qué Kinesis para procesar 5,000 msg/s?**

✅ **Respuesta**:  
"Kinesis es un log stream **persistente** (retention 24h) que permite procesamiento en tiempo real y recuperación de mensajes. Con 10 shards (auto-scale a 50), soportamos 10,000 msg/s. Shards se distribuyen por `vehicleId` (partition key) para garantizar orden por vehículo. Costo: **$0.015/shard-hora**."

**Ventajas sobre SQS**:
- Retención 24h vs 14 días configurables
- Múltiples consumidores (fan-out)
- Replay histórico
- Shard-level métricas

---

### **SQS FIFO**
**¿Por qué SQS FIFO para emergencias en vez de Kinesis?**

✅ **Respuesta**:  
"SQS FIFO garantiza **exactly-once processing** y orden de mensajes, crítico para emergencias. Con deduplication basado en MessageGroupId y FIFO throughput mode, procesamos 3,000 msg/seg con retraso <100ms. Kinesis introduciría ~1s de delay por batching. Costo: **$0.50/millon mensajes** + requests."

**Diferencias clave**:
- SQS FIFO: Guaranteed ordering, no deduplicación, batch size 1-10
- Kinesis: Shard ordering, duplicación posible, batches 100-500

---

### **Kinesis Firehose**
**¿Cómo optimizas el data lake con Firehose?**

✅ **Respuesta**:  
"Firehose consume de Kinesis y escribe a S3 en **formato Parquet**, con compresión 70% vs JSON. Partición automática por `year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}` para queries eficientes en Athena. Buffer de 5 min o 128 MB. Costo: **$0.029/GB procesado**."

**Pipeline**:
```
Kinesis → Firehose → S3 Parquet → Glue Crawler → Athena/QuickSight
```

---

### **Amazon SNS**
**¿Cómo garantizas que las emergencias lleguen a autoridades en <2s?**

✅ **Respuesta**:  
"SNS Topics (Authorities, Owner, Manager) permiten **múltiples suscriptores** paralelos (SMS, Email, Webhooks). En Step Functions se notifican en paralelo: Authorities + Owner + DynamoDB Incidents. SNS tiene SLA <100ms p99, garantizando notificaciones casi instantáneas."

**Suscripciones configuradas**:
- Authorities: SMS + Email
- Owner: SMS + Email + Push
- Manager: Email + SQS
- Alarms: Email + PagerDuty

---

## 💾 **STORAGE**

### **Amazon DynamoDB**
**¿Por qué DynamoDB On-Demand vs Provisioned?**

✅ **Respuesta**:  
"On-Demand billing escala automáticamente sin planning de capacidad, ideal para cargas impredecibles. Costo **2x** Provisioned en peak, pero **0.5x** en valleys. Para telemetría con spikes de emergencias, On-Demand elimina throttling. Point-in-Time Recovery y Streams habilitantage."

**Tablas**:
- Telemetry: Hash PK `vehicle_id`, Range SK `timestamp`, TTL 7 días
- Incidents: Hash PK `ulnerability_id`, GSI por vehicle/status
- WebSocket Connections: Hash PK `connection_id`, TTL para limpieza
- Alerts Config: Hash PK `user_id`, Range SK `alert_type`

---

### **Amazon RDS Aurora PostgreSQL**
**¿Por qué Aurora Serverless v2?**

✅ **Respuesta**:  
"Aurora Serverless v2 auto-scales de 0.5 a 16 ACUs sin downtime, ideal para cargas variables. Multi-AZ con failover <30s. PostgreSQL 15 con extensibilidad (JSONB, PostGIS). Costo: **~$0.12/ACU-hora** en us-east-1."

**Diferencia vs RDS simple**:
- Auto-scaling instantáneo (vs scaling manual 20-30 min)
- Pause/resume para dev (ahorro costos)
- Compatible con RDS PostgreSQL (migración sin cambios)

---

### **ElastiCache Redis**
**¿Por qué Redis en vez de DynamoDB para cache?**

✅ **Respuesta**:  
"Redis ofrece **sub-millisecond latency** vs DynamoDB ~10ms, y soporta estructuras complejas (lists, sets, sorted sets). Cacheamos últimas posiciones vehículos activos, sesiones usuario, y resultados queries frecuentes. 2 nodes multi-AZ con failover automático."

**Configuración**:
- Cache hit rate target: >90%
- Expiration: 300s para telemetría
- Persistence: AOF habilitado

---

### **Amazon S3**
**¿Cómo optimizas costos de storage con Lifecycle Policies?**

✅ **Respuesta**:  
"S3 Intelligent Tiering monitorea access patterns y mueve objetos a tiers menos costosos automáticamente. Videos a Glacier después de 7 días (85% ahorro), Data Lake a IA después de 90 días. Durabilidad 99.999999999% (11 9's) sin preocupaciones."

**Buckets**:
- Videos: Glacier después 7 días, expiración 365 días
- Data Lake: Intelligent Tiering 90 días, Glacier 180 días
- Logs: Expiración 30 días

---

### **Amazon Timestream**
**¿Por qué Timestream vs InfluxDB en ECS?**

✅ **Respuesta**:  
"Timestream es **serverless**, auto-scaling, con queries SQL nativas. Optimizado para series temporales con almacenamiento en 2 tiers: Memory Store (7 días acceso instantáneo) y Magnetic Store (12 meses costo optimizado). Costo: **$0.50/GB/mes** + queries $0.01/million."

**Ventajas**:
- No infraestructura que mantener
- Partición automática por tiempo
- Auto-scaling ilimitado

---

## ⚡ **COMPUTE**

### **AWS Lambda**
**¿Por qué Lambda sin VPC para procesadores de telemetría?**

✅ **Respuesta**:  
"Lambda fuera de VPC reduce **cold starts** de 10-60s a <1s (10-100x más rápido). DynamoDB/Kinesis son servicios AWS accesibles via backbone interno sin necesidad de VPC. Ahorro adicional: **~$50/mes** en ENI y NAT Gateway traffic. Para emergencias, cada milisegundo cuenta."

**Functions**:
- Telemetry Processor: 512 MB, timeout 60s, 100 concurrent
- Emergency Orchestrator: 256 MB, timeout 30s
- Anomaly Detector: 256 MB, timeout 15s
- WebSocket Handler: 256 MB, timeout 30s

---

### **Amazon ECS Fargate**
**¿Por qué Fargate vs EC2?**

✅ **Respuesta**:  
"Fargate elimina **gestión de servidores** - solo subes contenedores Docker. Auto-scaling basado en CPU/memoria (70%/80% thresholds). Target tracking policies ajustan tasks de 2-20 según demanda. Multi-AZ con Application Load Balancer para distribución. Costo: **$0.04/vCPU-hora + $0.004/GB-hora**."

**Servicios en ECS**:
- Monitoring Service (Node.js/Express)
- Auto-scaling 2-20 tasks
- Health checks cada 30s
- Blue/Green deployments

---

## 🌐 **API LAYER**

### **API Gateway REST**
**¿Por qué API Gateway vs ALB directo?**

✅ **Respuesta**:  
"API Gateway agrega **authorization** (Cognito JWT), rate limiting (1,000 req/seg por usuario), request/response transformación, caching, y WAF integration. Frontend consume una sola URL que enruta internamente a microservicios. Costo: **$3.50/millon requests**."

**Features**:
- Cognito authorization
- Request validation
- Response caching
- Stage variables para configuración

---

### **API Gateway WebSocket**
**¿Cómo manejas 10,000+ conexiones concurrentes?**

✅ **Respuesta**:  
"WebSocket API escala automáticamente a **10,000+ conexiones** sin configuración. Lambda maneja $connect/$disconnect/$subscribe, DynamoDB trackea connections activas. Broadcasts se envían vía `Management API` usando connection IDs. Costo: **$1.00/millon mensajes + $0.25/connection-hora**."

**Flujo**:
1. Cliente conecta → Lambda persiste en DynamoDB
2. Cliente subscribe → Lambda registra vehicle_ids
3. Telemetría update → Lambda lee DynamoDB, envía solo a subscribed clients

---

### **AWS AppSync (GraphQL)**
**¿Por qué GraphQL además de REST API?**

✅ **Respuesta**:  
"GraphQL permite que clientes **query solo los campos necesarios** (over-fetching reducido). Subscriptions permiten updates en tiempo real (vehículos en movimiento). Resolvers usan DynamoDB nativamente sin Lambda intermedia. Ideal para mobile apps con bandwidth limitado."

**Schema**:
- Query: `getVehicle(vehicleId: ID!): Vehicle`
- Subscription: `onVehicleUpdate(vehicleId: ID!): Vehicle`
- Resolvers VTL mapean DynamoDB directamente

---

## 🔀 **ORCHESTRATION**

### **AWS Step Functions**
**¿Cómo garantizas que emergencias se procesen en <2s?**

✅ **Respuesta**:  
"Step Functions ejecuta **tareas en paralelo** (notify authorities + owner + record incident + activate camera). Sin Lambda serial/sequential, el paralelismo reduce latencia de ~8s a <2s. State machine define workflow visual con retry/catch automáticos. Trazabilidad completa de cada emergencia."

**Pasos**:
1. Record Incident (DynamoDB) - Retry 3x, backoff 1.5x
2. Parallel Branch:
   - Notify Authorities (SNS)
   - Notify Owner (SNS)
   - Activate Video (Lambda)
3. Update Incident Status

---

### **Amazon EventBridge**
**¿Cómo desacoplas eventos entre servicios?**

✅ **Respuesta**:  
"EventBridge es un **event bus** para routing basado en patrones JSON (source, detail-type, detail). Por ejemplo: `detail.priority = "high"` → route a Kinesis separate lane. Esto permite agregar nuevos consumidores sin modificar publishers."

**Reglas**:
- High-priority telemetry → Separate Kinesis lane
- Payment events → Notify accounting
- Contract creation → Trigger workflow

---

## 🔍 **MONITORING**

### **Amazon CloudWatch**
**¿Cómo detectas cuellos de botella antes que afecten clientes?**

✅ **Respuesta**:  
"CloudWatch Dashboards agregan métricas de todos los servicios en vista unificada. Alarmas alertan cuando SQS queue depth > 1000 o Lambda duration > 2s. Logs Insights con queries SQL encuentran patrones en logs. Integración X-Ray para tracing distribuido end-to-end."

**Métricas clave**:
- Kinesis Iterator Age (debe ser < 1 min)
- Lambda Duration (p99 < 200ms)
- DynamoDB Throttling (0 throttles)
- ALB 5XX Errors (< 0.1%)

---

### **AWS X-Ray**
**¿Cómo rastrear transacciones complejas entre servicios?**

✅ **Respuesta**:  
"X-Ray genera **service map** visual de cada request pasando por Lambda → DynamoDB → SNS → Step Functions. Segmentos muestran latencia de cada servicio, permitiendo identificar cuellos de botella. Por ejemplo: si latency total es 1.8s, X-Ray muestra que 1.5s fue en DynamoDB."

**Traces habilitados**:
- Lambda functions
- API Gateway
- ECS services
- Step Functions
- DynamoDB

---

### **AWS GuardDuty**
**¿Cómo detectas amenazas de seguridad sin SIEM dedicado?**

✅ **Respuesta**:  
"GuardDuty analiza CloudTrail logs, VPC Flow Logs, y DNS logs con **machine learning** para detectar comportamiento anómalo (acceso desde IPs sospechosas, API calls raros, port scanning). Alertas vía SNS + PagerDuty. Costo: **$3.00/millon eventos CloudTrail**."

**Threats detectadas**:
- Port scanning
- Unauthorized API calls
- Crypto mining
- Data exfiltration attempts

---

## 🔐 **SECURITY**

### **AWS KMS**
**¿Cómo gestionas encryption keys sin compromiso de seguridad?**

✅ **Respuesta**:  
"KMS es **managed service** para encryption keys con rotación automática. Keys Customer Managed (no AWS Managed) dan control granular de policies. Encryption en reposo habilitado en DynamoDB, S3, RDS, ElastiCache. Encryption en tránsito vía TLS 1.3."

**Usage**:
- DynamoDB: SSE-KMS con customer managed key
- S3: SSE-KMS default encryption
- RDS: Encrypted storage (opcional)
- ElastiCache: Transit encryption at-rest

---

### **AWS Secrets Manager**
**¿Cómo almacenas passwords sin exponerlos en código?**

✅ **Respuesta**:  
"Secrets Manager almacena secrets (DB passwords, API keys) con **versioning** y rotación automática. Lambda/ECS recuperan secrets vía SDK con IAM roles, sin hardcodeo. Secrets encrypted con KMS. Costo: **$0.40/secret-mes + $0.05/10K API calls**."

**Secrets configurados**:
- Aurora DB password
- Redis auth token
- Stripe API key
- Government API credentials

---

### **AWS WAF**
**¿Cómo proteges APIs contra ataques DDoS y OWASP Top 10?**

✅ **Respuesta**:  
"WAF Regional asociado a API Gateway con Core Rule Set (OWASP Top 10), Cybersecurity Rule Set, rate limiting (2,000 req/5min por IP), y Known Bad Inputs. Logs a CloudWatch para forensics. Costo: **$1.00/mes + $0.60/million web requests**."

**Rules**:
- Rate limiting per IP
- SQL injection protection
- XSS protection
- Bad request blocking

---

### **Amazon Cognito**
**¿Por qué Cognito vs Auth0 u Okta?**

✅ **Respuesta**:  
"Cognito es **nativo AWS**, integrado con subsets IAM permissions y Lambda triggers (pre-signup, post-auth). User Pools con MFA TOTP, password policies, grupos RBAC (Admin, Viewer, Manager). Costo: **$0.0055/Monthly Active Users** vs Auth0 $240/mes base."

**Configuración**:
- User Pool con 5 grupos (Admin, Viewer, Purchaser, Approver, Manager)
- MFA habilitado
- Password policy: 12 chars, complexity
- JWT tokens: 1h access, 30d refresh

---

## 💰 **COST OPTIMIZATION**

### **¿Cómo optimizas costos sin sacrificar performance?**

✅ **Respuesta**:  
"Estrategia multi-faceta:

1. **Reserved Instances** (1 año): Aurora 35% descuento → $123/mes ahorro
2. **Savings Plans** (3 años): ECS/Lambda 50% descuento → $150/mes ahorro
3. **Lifecycle Policies**: S3 Intelligent Tiering + Glacier → 40% ahorro storage
4. **Auto-scaling**: Reduce capacidad en valleys → pago solo usage real
5. **VPC Endpoints**: Evita NAT Gateway charges → $29/mes ahorro

**Total optimizado**: $1,100/mes producción vs $1,500 sin optimización (**26% ahorro**)."

---

## ❓ **PREGUNTAS FRECUENTES**

### **¿Qué pasa si AWS tiene un outage?**

✅ **Respuesta**:  
"Arquitectura multi-AZ con failover automático. RDS Multi-AZ replica en standby (failover <30s). ElastiCache Redis Multi-AZ con read replicas. Si us-east-1 completo cae, backups en S3 permiten restore a otra región.opcional Cross-region replication. 99.9% SLA es **prometed** por AWS."

---

### **¿Cómo manejas picos de traffic (Black Friday, emergencias masivas)?**

✅ **Respuesta**:  
"Auto-scaling reactivo:
- Kinesis: 10 shards base → auto-scale a 50 (1,000 msg/s cada uno)
- Lambda: 100 concurrent executions
- ECS: 2-20 tasks según CPU/memoria
- DynamoDB On-Demand: Sin límite de capacity
- Aurora: 0.5-16 ACUs auto-scaling

Sin intervención manual, sistema escala de 1,000 a 10,000+ vehículos."

---

### **¿Qué sucede si un microservicio falla?**

✅ **Respuesta**:  
"Circuit Breaker pattern + retry automáticos:
- Lambda: 3 retries con exponential backoff
- DynamoDB: Throttling automático con retry
- ECS: Health checks reinician tasks unhealthy
- ALB: Route around unhealthy targets
- Dead Letter Queues capturan mensajes sin procesar

Architecture is **fail-safe** - un servicio caído no derriba sistema completo."

---

### **¿Cómo migrar de infraestructura actual sin downtime?**

✅ **Respuesta**:  
"Migración gradual:

**Fase 1**: Proveedores paralelos (dual-write)
- Dispositivos escriben a IoT Core y sistema legacy
- Validar parity de datos (1 semana)

**Fase 2**: Toggle gradual (feature flags)
- 10% traffic → AWS
- 50% traffic → AWS
- 100% traffic → AWS
- Rollback instantáneo si issues

**Fase 3**: Cutover DNS
- Route 53 switch + TTL bajo (60s)
- Monitoreo intensivo 24h

**Total downtime**: 0 segundos."

---

## 📊 **MÉTRICAS DE ÉXITO**

| Métrica | Target | Implementación |
|---------|--------|----------------|
| Emergency Response | <2s p99 | SQS FIFO + Step Functions |
| Telemetry Throughput | 5,000 msg/s | Kinesis 10 shards |
| API Availability | 99.9% | Multi-AZ + ALB |
| DB Read Latency | <10ms p95 | DynamoDB + Redis |
| Cache Hit Rate | avantajou |>90% | ElastiCache |

---

**Este documento te da respuestas técnicas sólidas y plagable para cualquier pregunta que te hagan. ¡Éxito en tu presentación!** 🚀

