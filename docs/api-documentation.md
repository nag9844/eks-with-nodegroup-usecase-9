# Flask API Documentation

## Overview

This Flask API provides a comprehensive user management system with full CRUD operations, search functionality, and monitoring capabilities.

## Base URL

```
http://your-domain.com/api
```

## Authentication

Currently, the API does not require authentication. In production, implement proper authentication mechanisms.

## Endpoints

### Health Check Endpoints

#### GET /
Returns the service status and basic information.

**Response:**
```json
{
  "status": "healthy",
  "service": "flask-api-microservice",
  "version": "1.0.0",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "environment": "production",
  "message": "Flask API is running successfully!"
}
```

#### GET /health
Kubernetes health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "checks": {
    "database": "ok",
    "redis": "ok"
  },
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

#### GET /readiness
Kubernetes readiness check endpoint.

**Response:**
```json
{
  "status": "ready",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### User Management Endpoints

#### GET /api/users
Get all users.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com",
      "age": 30
    }
  ],
  "count": 1,
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

#### POST /api/users
Create a new user.

**Request Body:**
```json
{
  "name": "Jane Smith",
  "email": "jane@example.com",
  "age": 25
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": 4,
    "name": "Jane Smith",
    "email": "jane@example.com",
    "age": 25,
    "created_at": "2024-01-15T10:30:00.000Z"
  },
  "message": "User created successfully"
}
```

#### GET /api/users/{id}
Get a specific user by ID.

**Response:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "age": 30
  }
}
```

#### PUT /api/users/{id}
Update a specific user by ID.

**Request Body:**
```json
{
  "name": "John Updated",
  "email": "john.updated@example.com",
  "age": 31
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "John Updated",
    "email": "john.updated@example.com",
    "age": 31,
    "updated_at": "2024-01-15T10:30:00.000Z"
  },
  "message": "User updated successfully"
}
```

#### DELETE /api/users/{id}
Delete a specific user by ID.

**Response:**
```json
{
  "success": true,
  "message": "User deleted successfully",
  "data": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "age": 30
  }
}
```

### Search and Statistics

#### GET /api/users/search?q={query}
Search users by name or email.

**Parameters:**
- `q` (required): Search query string

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com",
      "age": 30
    }
  ],
  "count": 1,
  "query": "john"
}
```

#### GET /api/stats
Get API statistics.

**Response:**
```json
{
  "success": true,
  "data": {
    "total_users": 3,
    "average_age": 30.0,
    "timestamp": "2024-01-15T10:30:00.000Z",
    "service_info": {
      "name": "Flask API Microservice",
      "version": "1.0.0",
      "environment": "production"
    }
  }
}
```

### Monitoring

#### GET /metrics
Prometheus metrics endpoint.

**Response:**
```
# HELP flask_app_requests_total Total number of requests
# TYPE flask_app_requests_total counter
flask_app_requests_total 30

# HELP flask_app_users_total Total number of users
# TYPE flask_app_users_total gauge
flask_app_users_total 3
```

## Error Responses

All error responses follow this format:

```json
{
  "success": false,
  "error": "Error message description",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### HTTP Status Codes

- `200` - Success
- `201` - Created
- `400` - Bad Request
- `404` - Not Found
- `405` - Method Not Allowed
- `409` - Conflict (e.g., email already exists)
- `500` - Internal Server Error

## Examples

### Create a User
```bash
curl -X POST http://localhost:5000/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Alice Johnson",
    "email": "alice@example.com",
    "age": 28
  }'
```

### Get All Users
```bash
curl http://localhost:5000/api/users
```

### Search Users
```bash
curl "http://localhost:5000/api/users/search?q=alice"
```

### Update a User
```bash
curl -X PUT http://localhost:5000/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Alice Updated",
    "age": 29
  }'
```

### Delete a User
```bash
curl -X DELETE http://localhost:5000/api/users/1
```

## Testing

Run the test suite:

```bash
cd app
pip install -r requirements-dev.txt
pytest test_app.py -v
```

Run with coverage:

```bash
coverage run -m pytest test_app.py -v
coverage report
```