import pytest
import json
from app import app, books

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        # Reset books data for each test
        global books
        books.clear()
        books.extend([
            {"id": 1, "title": "Java book", "author": "Test Author", "year": 2020, "isbn": "123456789"},
            {"id": 2, "title": "Python book", "author": "Test Author 2", "year": 2021, "isbn": "987654321"}
        ])
        yield client

def test_home_endpoint(client):
    """Test the home endpoint"""
    response = client.get('/')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'healthy'
    assert data['service'] == 'flask-books-api'

def test_health_check(client):
    """Test the health check endpoint"""
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'healthy'

def test_readiness_check(client):
    """Test the readiness check endpoint"""
    response = client.get('/readiness')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'ready'

def test_get_books(client):
    """Test getting all books"""
    response = client.get('/books')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['success'] == True
    assert 'data' in data
    assert isinstance(data['data'], list)
    assert len(data['data']) == 2

def test_get_book_by_id(client):
    """Test getting a specific book by ID"""
    response = client.get('/books/1')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['success'] == True
    assert data['data']['id'] == 1
    assert data['data']['title'] == 'Java book'

def test_get_nonexistent_book(client):
    """Test getting a non-existent book"""
    response = client.get('/books/999')
    assert response.status_code == 404
    data = json.loads(response.data)
    assert data['success'] == False
    assert data['error'] == 'Book not found'

def test_create_book(client):
    """Test creating a new book"""
    new_book = {
        'title': 'Test Book',
        'author': 'Test Author',
        'year': 2024,
        'isbn': '978-1234567890'
    }
    response = client.post('/books', 
                          data=json.dumps(new_book),
                          content_type='application/json')
    assert response.status_code == 201
    data = json.loads(response.data)
    assert data['success'] == True
    assert data['data']['title'] == 'Test Book'
    assert data['data']['author'] == 'Test Author'

def test_create_book_missing_fields(client):
    """Test creating a book with missing required fields"""
    incomplete_book = {'title': 'Test Book'}
    response = client.post('/books',
                          data=json.dumps(incomplete_book),
                          content_type='application/json')
    assert response.status_code == 400
    data = json.loads(response.data)
    assert data['success'] == False
    assert 'Missing required field' in data['error']

def test_update_book(client):
    """Test updating a book"""
    updated_book = {
        'title': 'Updated Java Book',
        'author': 'Updated Author',
        'year': 2023
    }
    response = client.put('/books/1',
                         data=json.dumps(updated_book),
                         content_type='application/json')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['success'] == True
    assert data['data']['title'] == 'Updated Java Book'
    assert data['data']['author'] == 'Updated Author'

def test_update_nonexistent_book(client):
    """Test updating a non-existent book"""
    updated_book = {'title': 'Updated Book'}
    response = client.put('/books/999',
                         data=json.dumps(updated_book),
                         content_type='application/json')
    assert response.status_code == 404
    data = json.loads(response.data)
    assert data['success'] == False
    assert data['error'] == 'Book not found'

def test_delete_book(client):
    """Test deleting a book"""
    response = client.delete('/books/1')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['success'] == True
    assert data['message'] == 'Book deleted successfully'
    
    # Verify book is deleted
    response = client.get('/books/1')
    assert response.status_code == 404

def test_delete_nonexistent_book(client):
    """Test deleting a non-existent book"""
    response = client.delete('/books/999')
    assert response.status_code == 404
    data = json.loads(response.data)
    assert data['success'] == False
    assert data['error'] == 'Book not found'

def test_swagger_config(client):
    """Test swagger configuration endpoint"""
    response = client.get('/swagger-config')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'openapi' in data
    assert data['info']['title'] == 'Flask Books API'

def test_metrics_endpoint(client):
    """Test the metrics endpoint"""
    response = client.get('/metrics')
    assert response.status_code == 200
    assert 'flask_books_total' in response.data.decode()

def test_404_error(client):
    """Test 404 error handling"""
    response = client.get('/nonexistent-endpoint')
    assert response.status_code == 404
    data = json.loads(response.data)
    assert data['success'] == False
    assert data['error'] == 'Endpoint not found'