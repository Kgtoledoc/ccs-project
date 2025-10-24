# API Module

This module implements API Gateway (REST and WebSocket) and AWS AppSync for the CCS platform.

## Resources Created

### API Gateway REST API
- **REST API**: HTTP/HTTPS endpoints
- **Cognito Authorizer**: JWT-based authentication
- **VPC Link**: Private integration with ALB
- **WAF Integration**: Web application firewall
- **CloudWatch Logs**: API access logs

### API Gateway WebSocket
- **WebSocket API**: Real-time bidirectional communication
- **Routes**: $connect, $disconnect, subscribe, ping
- **Lambda Integration**: WebSocket handler
- **Custom Authorizer**: Token-based authentication
- **Auto-scaling**: Handles 1,000 messages/second

### AWS AppSync
- **GraphQL API**: Modern data query and manipulation
- **Real-time Subscriptions**: Live updates
- **DynamoDB Data Source**: Direct integration
- **Cognito Authentication**: User pool integration
- **X-Ray Tracing**: Performance monitoring

## API Gateway REST API

### Endpoints

#### GET /vehicles/{vehicleId}
- **Auth**: Cognito User Pool
- **Description**: Get current vehicle status
- **Response**: Vehicle telemetry data

```bash
curl -H "Authorization: Bearer <jwt-token>" \
  https://<api-id>.execute-api.us-east-1.amazonaws.com/prod/vehicles/VEH-12345
```

**Response**:
```json
{
  "vehicle_id": "VEH-12345",
  "timestamp": 1698765432000,
  "location": {
    "lat": 4.6097,
    "lon": -74.0817
  },
  "speed": 65.5,
  "status": "moving"
}
```

### Authentication

1. **Get JWT Token from Cognito**:
```bash
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id <client-id> \
  --auth-parameters USERNAME=user@example.com,PASSWORD=password
```

2. **Use Token in API Requests**:
```bash
curl -H "Authorization: Bearer <id-token>" \
  https://<api-url>/vehicles/VEH-12345
```

## WebSocket API

### Connection

```javascript
const socket = new WebSocket(
  'wss://<api-id>.execute-api.us-east-1.amazonaws.com/prod?token=<jwt-token>'
);

socket.onopen = () => {
  console.log('Connected');
  
  // Subscribe to vehicles
  socket.send(JSON.stringify({
    action: 'subscribe',
    vehicleIds: ['VEH-12345', 'VEH-67890']
  }));
};

socket.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Vehicle update:', data);
};

// Ping to keep connection alive
setInterval(() => {
  socket.send(JSON.stringify({ action: 'ping' }));
}, 60000);
```

### Routes

#### $connect
- **Trigger**: Client connects
- **Auth**: Custom authorizer (query param token)
- **Action**: Store connection in DynamoDB

#### $disconnect
- **Trigger**: Client disconnects
- **Action**: Remove connection from DynamoDB

#### subscribe
- **Payload**: `{ action: 'subscribe', vehicleIds: ['VEH-1', 'VEH-2'] }`
- **Action**: Subscribe to vehicle updates

#### ping
- **Payload**: `{ action: 'ping' }`
- **Response**: Keep-alive acknowledgment

### Broadcasting Updates

When telemetry is updated, broadcast to all subscribed clients:

```javascript
// Lambda function to broadcast (triggered by DynamoDB Stream)
const AWS = require('aws-sdk');
const apigateway = new AWS.ApiGatewayManagementApi({
  endpoint: 'https://<api-id>.execute-api.us-east-1.amazonaws.com/prod'
});

async function broadcastUpdate(vehicleId, data) {
  // Get subscribed connections
  const connections = await getSubscribedConnections(vehicleId);
  
  // Send to each connection
  for (const connectionId of connections) {
    await apigateway.postToConnection({
      ConnectionId: connectionId,
      Data: JSON.stringify({
        type: 'vehicle_update',
        vehicleId,
        data
      })
    }).promise();
  }
}
```

## AWS AppSync (GraphQL)

### Schema

```graphql
type Vehicle {
  vehicleId: ID!
  timestamp: AWSTimestamp!
  location: Location
  speed: Float
  status: String
}

type Query {
  getVehicle(vehicleId: ID!): Vehicle
  listVehicles(limit: Int): [Vehicle]
}

type Mutation {
  updateVehicle(vehicleId: ID!, location: LocationInput, speed: Float): Vehicle
}

type Subscription {
  onVehicleUpdate(vehicleId: ID!): Vehicle
}
```

### Queries

#### Get Vehicle
```graphql
query GetVehicle {
  getVehicle(vehicleId: "VEH-12345") {
    vehicleId
    timestamp
    location {
      lat
      lon
    }
    speed
    status
  }
}
```

#### List Vehicles
```graphql
query ListVehicles {
  listVehicles(limit: 10) {
    vehicleId
    speed
    status
  }
}
```

### Mutations

```graphql
mutation UpdateVehicle {
  updateVehicle(
    vehicleId: "VEH-12345"
    location: { lat: 4.6097, lon: -74.0817 }
    speed: 65.5
  ) {
    vehicleId
    timestamp
    location {
      lat
      lon
    }
  }
}
```

### Subscriptions

```graphql
subscription OnVehicleUpdate {
  onVehicleUpdate(vehicleId: "VEH-12345") {
    vehicleId
    location {
      lat
      lon
    }
    speed
    status
  }
}
```

### Client Example (JavaScript)

```javascript
import { ApolloClient, InMemoryCache, gql } from '@apollo/client';
import { createSubscriptionHandshakeLink } from 'aws-appsync-subscription-link';

const config = {
  url: 'https://<api-id>.appsync-api.us-east-1.amazonaws.com/graphql',
  region: 'us-east-1',
  auth: {
    type: 'AMAZON_COGNITO_USER_POOLS',
    jwtToken: async () => getCognitoToken()
  }
};

const client = new ApolloClient({
  link: createSubscriptionHandshakeLink(config),
  cache: new InMemoryCache()
});

// Query
const { data } = await client.query({
  query: gql`
    query GetVehicle {
      getVehicle(vehicleId: "VEH-12345") {
        vehicleId
        speed
      }
    }
  `
});

// Subscription
client.subscribe({
  query: gql`
    subscription OnVehicleUpdate {
      onVehicleUpdate(vehicleId: "VEH-12345") {
        vehicleId
        location { lat lon }
        speed
      }
    }
  `
}).subscribe({
  next: ({ data }) => console.log('Update:', data),
  error: (error) => console.error('Error:', error)
});
```

## Performance

### API Gateway REST
- **Request Limit**: 10,000 requests/second
- **Timeout**: 29 seconds
- **Payload Size**: 10 MB
- **Throttling**: Per-client throttling available

### WebSocket API
- **Connections**: 100,000 concurrent
- **Message Rate**: 1,000 messages/second per connection
- **Idle Timeout**: 10 minutes (configurable)
- **Message Size**: 128 KB

### AppSync
- **Request Limit**: 5,000 requests/second
- **Subscriptions**: 100,000 concurrent
- **Response Size**: 1 MB
- **Query Complexity**: Configurable

## Cost Optimization

### API Gateway REST
- **First 333M requests**: $3.50 per million
- **Next 667M requests**: $2.80 per million
- **VPC Link**: $0.025/hour (~$18/month)
- **Data Transfer**: Standard AWS rates

### WebSocket API
- **Connection Minutes**: $0.25 per million
- **Messages**: $1.00 per million
- **Example**: 1,000 users × 24h × 30 days = $18/month

### AppSync
- **Query/Mutation**: $4.00 per million
- **Real-time Updates**: $2.00 per million
- **Example**: 100K requests/day = $12/month

## Security

### REST API
- ✅ Cognito JWT validation
- ✅ WAF protection
- ✅ VPC Link (private integration)
- ✅ TLS 1.2+
- ✅ Resource policies

### WebSocket
- ✅ Custom authorizer
- ✅ Connection validation
- ✅ Rate limiting (1,000 msg/s)
- ✅ Idle timeout (10 min)

### AppSync
- ✅ Cognito authentication
- ✅ Field-level authorization
- ✅ Query depth limiting
- ✅ X-Ray tracing

## Monitoring

### CloudWatch Metrics
- **REST API**: Count, 4XXError, 5XXError, Latency, IntegrationLatency
- **WebSocket**: ConnectionCount, MessageCount, IntegrationError
- **AppSync**: 4XXError, 5XXError, Latency, ConnectedDevice

### CloudWatch Logs
- Access logs (JSON format)
- Execution logs (error level)
- X-Ray traces

## Testing

### Test REST API
```bash
# Get JWT token
TOKEN=$(aws cognito-idp initiate-auth ... | jq -r '.AuthenticationResult.IdToken')

# Test endpoint
curl -H "Authorization: Bearer $TOKEN" \
  https://<api-url>/vehicles/VEH-12345
```

### Test WebSocket
```bash
# Install wscat
npm install -g wscat

# Connect
wscat -c 'wss://<api-id>.execute-api.us-east-1.amazonaws.com/prod?token=<token>'

# Send message
> {"action":"subscribe","vehicleIds":["VEH-12345"]}
```

### Test AppSync
Use AWS Console → AppSync → Queries or:
```bash
# Install amplify CLI
npm install -g @aws-amplify/cli

# Test query
amplify api gql-query --operation GetVehicle --variables '{"vehicleId":"VEH-12345"}'
```

## Troubleshooting

### 403 Forbidden
**Problem**: Cognito authorizer fails  
**Solution**: Verify JWT token is valid and not expired

### 504 Gateway Timeout
**Problem**: Lambda/ALB timeout  
**Solution**: Increase timeout, optimize backend

### WebSocket Connection Drops
**Problem**: Idle timeout or network issue  
**Solution**: Implement ping/pong keep-alive

## Usage

```hcl
module "api" {
  source = "./modules/api"

  project_name                   = "ccs"
  environment                    = "prod"
  vpc_id                         = module.networking.vpc_id
  load_balancer_arn              = module.compute.load_balancer_arn
  load_balancer_dns              = module.compute.load_balancer_dns
  websocket_handler_arn          = module.compute.websocket_handler_arn
  cognito_user_pool_id           = module.security.cognito_user_pool_id
  cognito_user_pool_arn          = module.security.cognito_user_pool_arn
  waf_web_acl_arn                = module.security.waf_web_acl_arn
  dynamodb_telemetry_table_name  = module.storage.dynamodb_telemetry_table_name
  appsync_role_arn               = module.security.appsync_role_arn
  kms_key_id                     = module.security.kms_key_id
  enable_xray                    = true

  tags = {
    Project = "CCS"
  }
}
```

## References

- [API Gateway Developer Guide](https://docs.aws.amazon.com/apigateway/latest/developerguide/)
- [WebSocket API](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-websocket-api.html)
- [AppSync Developer Guide](https://docs.aws.amazon.com/appsync/latest/devguide/)
- [GraphQL Best Practices](https://graphql.org/learn/best-practices/)

