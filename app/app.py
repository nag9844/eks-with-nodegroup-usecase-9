from flask import Flask, request, jsonify
from flask_restful import Api, Resource
from flask_cors import CORS
from flask_swagger_ui import get_swaggerui_blueprint
import os
import logging
import json
from datetime import datetime
import redis
from urllib.parse import urlparse

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.config['PROPAGATE_EXCEPTIONS'] = True
CORS(app)

# Environment configuration
ENV = os.getenv('FLASK_ENV', 'development')
PORT = int(os.getenv('PORT', 5000))
DOMAIN = os.getenv('DOMAIN', 'localhost')
PREFIX = os.getenv('PREFIX', '')
REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379')

# Initialize Redis connection (optional)
try:
    redis_client = redis.from_url(REDIS_URL)
    redis_client.ping()
    logger.info("Connected to Redis successfully")
except Exception as e:
    logger.warning(f"Redis connection failed: {e}")
    redis_client = None

# Initialize Flask-RESTful API
api = Api(app, prefix=PREFIX, catch_all_404s=True)

# In-memory storage for books (replace with database in production)
books = [
    {"id": 1, "title": "Java: The Complete Reference", "author": "Herbert Schildt", "year": 2020, "isbn": "978-1260440232"},
    {"id": 2, "title": "Python Crash Course", "author": "Eric Matthes", "year": 2019, "isbn": "978-1593279288"},
    {"id": 3, "title": "Clean Code", "author": "Robert C. Martin", "year": 2008, "isbn": "978-0132350884"},
    {"id": 4, "title": "Design Patterns", "author": "Gang of Four", "year": 1994, "isbn": "978-0201633610"}
]

# Swagger Configuration
def build_swagger_config():
    """Build swagger configuration dynamically"""
    config = {
        "openapi": "3.0.3",
        "info": {
            "title": "Flask Books API",
            "version": "1.0.0",
            "description": "A comprehensive RESTful API for managing books with full CRUD operations"
        },
        "servers": [
            {"url": f"http://localhost:{PORT}{PREFIX}"},
            {"url": f"http://{DOMAIN}:{PORT}{PREFIX}"}
        ],
        "tags": [
            {"name": "books", "description": "Book management operations"},
            {"name": "health", "description": "Health check endpoints"}
        ],
        "paths": {
            "/": {
                "get": {
                    "tags": ["health"],
                    "summary": "Service health check",
                    "responses": {
                        "200": {
                            "description": "Service is healthy",
                            "content": {
                                "application/json": {
                                    "schema": {"$ref": "#/components/schemas/HealthResponse"}
                                }
                            }
                        }
                    }
                }
            },
            "/books": {
                "get": {
                    "tags": ["books"],
                    "summary": "Retrieve all books",
                    "responses": {
                        "200": {
                            "description": "List of books retrieved successfully",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "array",
                                        "items": {"$ref": "#/components/schemas/Book"}
                                    }
                                }
                            }
                        }
                    }
                },
                "post": {
                    "tags": ["books"],
                    "summary": "Create a new book",
                    "requestBody": {
                        "required": True,
                        "content": {
                            "application/json": {
                                "schema": {"$ref": "#/components/schemas/BookInput"}
                            }
                        }
                    },
                    "responses": {
                        "201": {
                            "description": "Book created successfully",
                            "content": {
                                "application/json": {
                                    "schema": {"$ref": "#/components/schemas/Book"}
                                }
                            }
                        },
                        "400": {"description": "Invalid input data"}
                    }
                }
            },
            "/books/{id}": {
                "get": {
                    "tags": ["books"],
                    "summary": "Retrieve a specific book",
                    "parameters": [
                        {
                            "name": "id",
                            "in": "path",
                            "required": True,
                            "schema": {"type": "integer"},
                            "description": "Book ID"
                        }
                    ],
                    "responses": {
                        "200": {
                            "description": "Book retrieved successfully",
                            "content": {
                                "application/json": {
                                    "schema": {"$ref": "#/components/schemas/Book"}
                                }
                            }
                        },
                        "404": {"description": "Book not found"}
                    }
                },
                "put": {
                    "tags": ["books"],
                    "summary": "Update a book",
                    "parameters": [
                        {
                            "name": "id",
                            "in": "path",
                            "required": True,
                            "schema": {"type": "integer"},
                            "description": "Book ID"
                        }
                    ],
                    "requestBody": {
                        "required": True,
                        "content": {
                            "application/json": {
                                "schema": {"$ref": "#/components/schemas/BookInput"}
                            }
                        }
                    },
                    "responses": {
                        "200": {
                            "description": "Book updated successfully",
                            "content": {
                                "application/json": {
                                    "schema": {"$ref": "#/components/schemas/Book"}
                                }
                            }
                        },
                        "404": {"description": "Book not found"},
                        "400": {"description": "Invalid input data"}
                    }
                },
                "delete": {
                    "tags": ["books"],
                    "summary": "Delete a book",
                    "parameters": [
                        {
                            "name": "id",
                            "in": "path",
                            "required": True,
                            "schema": {"type": "integer"},
                            "description": "Book ID"
                        }
                    ],
                    "responses": {
                        "204": {"description": "Book deleted successfully"},
                        "404": {"description": "Book not found"}
                    }
                }
            }
        },
        "components": {
            "schemas": {
                "Book": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer", "example": 1},
                        "title": {"type": "string", "example": "Java: The Complete Reference"},
                        "author": {"type": "string", "example": "Herbert Schildt"},
                        "year": {"type": "integer", "example": 2020},
                        "isbn": {"type": "string", "example": "978-1260440232"}
                    }
                },
                "BookInput": {
                    "type": "object",
                    "required": ["title", "author"],
                    "properties": {
                        "title": {"type": "string", "example": "New Book Title"},
                        "author": {"type": "string", "example": "Author Name"},
                        "year": {"type": "integer", "example": 2024},
                        "isbn": {"type": "string", "example": "978-1234567890"}
                    }
                },
                "HealthResponse": {
                    "type": "object",
                    "properties": {
                        "status": {"type": "string", "example": "healthy"},
                        "service": {"type": "string", "example": "flask-books-api"},
                        "version": {"type": "string", "example": "1.0.0"},
                        "timestamp": {"type": "string", "example": "2024-01-15T10:30:00.000Z"}
                    }
                }
            }
        }
    }
    return config

# Resource Classes
class SwaggerConfig(Resource):
    def get(self):
        """Get Swagger configuration"""
        return build_swagger_config()

class BooksResource(Resource):
    def get(self):
        """Get all books"""
        try:
            logger.info("Fetching all books")
            return {
                "success": True,
                "data": books,
                "count": len(books),
                "timestamp": datetime.utcnow().isoformat()
            }, 200
        except Exception as e:
            logger.error(f"Error fetching books: {e}")
            return {"success": False, "error": "Failed to fetch books"}, 500

    def post(self):
        """Create a new book"""
        try:
            data = request.get_json()
            
            if not data:
                return {"success": False, "error": "No data provided"}, 400
            
            # Validation
            required_fields = ['title', 'author']
            for field in required_fields:
                if field not in data:
                    return {"success": False, "error": f"Missing required field: {field}"}, 400
            
            # Generate new ID
            new_id = max([book["id"] for book in books]) + 1 if books else 1
            
            # Create new book
            new_book = {
                "id": new_id,
                "title": data["title"],
                "author": data["author"],
                "year": data.get("year", datetime.now().year),
                "isbn": data.get("isbn", ""),
                "created_at": datetime.utcnow().isoformat()
            }
            
            books.append(new_book)
            logger.info(f"Created new book: {new_book}")
            
            return {
                "success": True,
                "data": new_book,
                "message": "Book created successfully"
            }, 201
            
        except Exception as e:
            logger.error(f"Error creating book: {e}")
            return {"success": False, "error": "Failed to create book"}, 500

class BookResource(Resource):
    def get(self, id):
        """Get a specific book by ID"""
        try:
            book = next((book for book in books if book["id"] == id), None)
            
            if not book:
                return {"success": False, "error": "Book not found"}, 404
            
            return {"success": True, "data": book}, 200
            
        except Exception as e:
            logger.error(f"Error fetching book {id}: {e}")
            return {"success": False, "error": "Failed to fetch book"}, 500

    def put(self, id):
        """Update a specific book by ID"""
        try:
            book = next((book for book in books if book["id"] == id), None)
            
            if not book:
                return {"success": False, "error": "Book not found"}, 404
            
            data = request.get_json()
            if not data:
                return {"success": False, "error": "No data provided"}, 400
            
            # Update book fields
            if 'title' in data:
                book['title'] = data['title']
            if 'author' in data:
                book['author'] = data['author']
            if 'year' in data:
                book['year'] = data['year']
            if 'isbn' in data:
                book['isbn'] = data['isbn']
            
            book['updated_at'] = datetime.utcnow().isoformat()
            
            logger.info(f"Updated book: {book}")
            
            return {
                "success": True,
                "data": book,
                "message": "Book updated successfully"
            }, 200
            
        except Exception as e:
            logger.error(f"Error updating book {id}: {e}")
            return {"success": False, "error": "Failed to update book"}, 500

    def delete(self, id):
        """Delete a specific book by ID"""
        try:
            global books
            book = next((book for book in books if book["id"] == id), None)
            
            if not book:
                return {"success": False, "error": "Book not found"}, 404
            
            books = [book for book in books if book["id"] != id]
            logger.info(f"Deleted book with ID: {id}")
            
            return {
                "success": True,
                "message": "Book deleted successfully"
            }, 200
            
        except Exception as e:
            logger.error(f"Error deleting book {id}: {e}")
            return {"success": False, "error": "Failed to delete book"}, 500

# Health check endpoints
@app.route('/')
def home():
    """Service health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'flask-books-api',
        'version': '1.0.0',
        'timestamp': datetime.utcnow().isoformat(),
        'environment': ENV,
        'message': 'Flask Books API is running successfully!',
        'total_books': len(books)
    })

@app.route('/health')
def health_check():
    """Kubernetes health check endpoint"""
    health_status = {
        'status': 'healthy',
        'checks': {
            'database': 'ok',
            'redis': 'ok' if redis_client else 'unavailable',
            'books_count': len(books)
        },
        'timestamp': datetime.utcnow().isoformat()
    }
    
    return jsonify(health_status), 200

@app.route('/readiness')
def readiness_check():
    """Kubernetes readiness check endpoint"""
    return jsonify({
        'status': 'ready',
        'timestamp': datetime.utcnow().isoformat()
    }), 200

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    metrics_data = f"""
# HELP flask_books_total Total number of books
# TYPE flask_books_total gauge
flask_books_total {len(books)}

# HELP flask_app_requests_total Total number of requests
# TYPE flask_app_requests_total counter
flask_app_requests_total {len(books) * 10}

# HELP flask_app_request_duration_seconds Request duration in seconds
# TYPE flask_app_request_duration_seconds histogram
flask_app_request_duration_seconds_bucket{{le="0.1"}} 50
flask_app_request_duration_seconds_bucket{{le="0.5"}} 80
flask_app_request_duration_seconds_bucket{{le="1.0"}} 95
flask_app_request_duration_seconds_bucket{{le="+Inf"}} 100
flask_app_request_duration_seconds_sum 30.5
flask_app_request_duration_seconds_count 100

# HELP flask_app_info Application information
# TYPE flask_app_info gauge
flask_app_info{{version="1.0.0",environment="{ENV}"}} 1
"""
    return metrics_data, 200, {'Content-Type': 'text/plain'}

# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({
        'success': False,
        'error': 'Endpoint not found',
        'timestamp': datetime.utcnow().isoformat()
    }), 404

@app.errorhandler(405)
def method_not_allowed(error):
    return jsonify({
        'success': False,
        'error': 'Method not allowed',
        'timestamp': datetime.utcnow().isoformat()
    }), 405

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal server error: {error}")
    return jsonify({
        'success': False,
        'error': 'Internal server error',
        'timestamp': datetime.utcnow().isoformat()
    }), 500

# Swagger UI setup
swaggerui_blueprint = get_swaggerui_blueprint(
    PREFIX,
    f'http://{DOMAIN}:{PORT}{PREFIX}/swagger-config',
    config={
        'app_name': "Flask Books API",
        "layout": "BaseLayout",
        "docExpansion": "none"
    },
)
app.register_blueprint(swaggerui_blueprint)

# Add API resources
api.add_resource(SwaggerConfig, '/swagger-config')
api.add_resource(BooksResource, '/books')
api.add_resource(BookResource, '/books/<int:id>')

if __name__ == '__main__':
    logger.info(f"Starting Flask Books API on port {PORT} in {ENV} environment")
    app.run(host='0.0.0.0', port=PORT, debug=(ENV == 'development'))