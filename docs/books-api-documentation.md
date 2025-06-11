# Flask Books API Documentation

## Overview

This Flask Books API provides a comprehensive book management system with full CRUD operations, Swagger documentation, and monitoring capabilities. The API follows RESTful principles and includes proper error handling, logging, and health checks.

## Features

- **Complete CRUD Operations**: Create, Read, Update, Delete books
- **Swagger Documentation**: Interactive API documentation
- **Health Checks**: Kubernetes-ready health and readiness probes
- **Monitoring**: Prometheus metrics endpoint
- **Error Handling**: Comprehensive error responses
- **Logging**: Structured logging throughout the application
- **Redis Integration**: Optional Redis support for caching/sessions

## Base URL

```
http://your-domain.com
```

## Swagger Documentation

Access the interactive Swagger UI at:
```
http://your-domain.com/
```

## API Endpoints

### Health Check Endpoints

#### GET /
Returns the service status and basic information.

**Response:**
```json
{
  "status": "healthy",
  "service": "flask-books-api",
  "version": "1.0.0",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "environment": "production",
  "message": "Flask Books API is running successfully!",
  "total_books": 4
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
    "redis": "ok",
    "books_count": 4
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

### Book Management Endpoints

#### GET /books
Get all books.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "title": "Java: The Complete Reference",
      "author": "Herbert Schildt",
      "year": 2020,
      "isbn": "978-1260440232"
    },
    {
      "id": 2,
      "title": "Python Crash Course",
      "author": "Eric Matthes",
      "year": 2019,
      "isbn": "978-1593279288"
    }
  ],
  "count": 2,
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

#### POST /books
Create a new book.

**Request Body:**
```json
{
  "title": "New Programming Book",
  "author": "John Developer",
  "year": 2024,
  "isbn": "978-1234567890"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": 5,
    "title": "New Programming Book",
    "author": "John Developer",
    "year": 2024,
    "isbn": "978-1234567890",
    "created_at": "2024-01-15T10:30:00.000Z"
  },
  "message": "Book created successfully"
}
```

#### GET /books/{id}
Get a specific book by ID.

**Response:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "title": "Java: The Complete Reference",
    "author": "Herbert Schildt",
    "year": 2020,
    "isbn": "978-1260440232"
  }
}
```

#### PUT /books/{id}
Update a specific book by ID.

**Request Body:**
```json
{
  "title": "Java: The Complete Reference - Updated Edition",
  "author": "Herbert Schildt",
  "year": 2024,
  "isbn": "978-1260440232"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "title": "Java: The Complete Reference - Updated Edition",
    "author": "Herbert Schildt",
    "year": 2024,
    "isbn": "978-1260440232",
    "updated_at": "2024-01-15T10:30:00.000Z"
  },
  "message": "Book updated successfully"
}
```

#### DELETE /books/{id}
Delete a specific book by ID.

**Response:**
```json
{
  "success": true,
  "message": "Book deleted successfully"
}
```

### Monitoring

#### GET /metrics
Prometheus metrics endpoint.

**Response:**
```
# HELP flask_books_total Total number of books
# TYPE flask_books_total gauge
flask_books_total 4

# HELP flask_app_requests_total Total number of requests
# TYPE flask_app_requests_total counter
flask_app_requests_total 40
```

#### GET /swagger-config
Get Swagger configuration (used by Swagger UI).

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
- `500` - Internal Server Error

## Examples

### Create a Book
```bash
curl -X POST http://localhost:5000/books \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Docker Deep Dive",
    "author": "Nigel Poulton",
    "year": 2023,
    "isbn": "978-1521822807"
  }'
```

### Get All Books
```bash
curl http://localhost:5000/books
```

### Get a Specific Book
```bash
curl http://localhost:5000/books/1
```

### Update a Book
```bash
curl -X PUT http://localhost:5000/books/1 \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Docker Deep Dive - Updated Edition",
    "year": 2024
  }'
```

### Delete a Book
```bash
curl -X DELETE http://localhost:5000/books/1
```

## Environment Variables

The application supports the following environment variables:

- `FLASK_ENV`: Environment mode (development/production)
- `PORT`: Port number (default: 5000)
- `DOMAIN`: Domain name (default: localhost)
- `PREFIX`: URL prefix (default: empty)
- `REDIS_URL`: Redis connection URL

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

## Docker Usage

Build and run with Docker:

```bash
# Build the image
docker build -t flask-books-api .

# Run the container
docker run -p 5000:5000 flask-books-api
```

## Kubernetes Deployment

The application includes Kubernetes manifests for deployment to EKS:

- Health checks configured for liveness and readiness probes
- Resource limits and requests defined
- Redis integration for session storage
- Horizontal Pod Autoscaler (HPA) support

## Architecture

The application follows a modular structure:

- **Flask-RESTful**: For REST API endpoints
- **Flask-CORS**: For cross-origin resource sharing
- **Flask-Swagger-UI**: For interactive API documentation
- **Redis**: Optional caching and session storage
- **Prometheus**: Metrics collection
- **Gunicorn**: Production WSGI server

This design ensures scalability, maintainability, and production readiness.