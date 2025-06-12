from flask import Flask, jsonify, request
import os
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Health check endpoint
@app.route('/health')
def health_check():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'service': 'flask-microservice'
    }), 200

# Root endpoint
@app.route('/')
def home():
    return jsonify({
        'message': 'Welcome to Flask Microservice on EKS!',
        'version': '1.0.0',
        'timestamp': datetime.utcnow().isoformat()
    })

# API endpoint
@app.route('/api/users', methods=['GET'])
def get_users():
    users = [
        {'id': 1, 'name': 'John Doe', 'email': 'john@example.com'},
        {'id': 2, 'name': 'Jane Smith', 'email': 'jane@example.com'},
        {'id': 3, 'name': 'Bob Johnson', 'email': 'bob@example.com'}
    ]
    return jsonify({'users': users})

# POST endpoint
@app.route('/api/users', methods=['POST'])
def create_user():
    data = request.get_json()
    if not data or 'name' not in data or 'email' not in data:
        return jsonify({'error': 'Name and email are required'}), 400
    
    new_user = {
        'id': 4,  # In real app, this would be generated
        'name': data['name'],
        'email': data['email']
    }
    
    logger.info(f"Created new user: {new_user}")
    return jsonify({'user': new_user}), 201

# Metrics endpoint for monitoring
@app.route('/metrics')
def metrics():
    return jsonify({
        'requests_total': 100,  # In real app, this would be tracked
        'uptime_seconds': 3600,
        'memory_usage_mb': 128
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)