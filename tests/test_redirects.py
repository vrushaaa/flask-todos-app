import pytest
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import create_app



@pytest.fixture
def app():
    """Create and configure a new app instance for testing."""
    app = create_app()
    app.config.update({
        "TESTING": True,
        "SQLALCHEMY_DATABASE_URI": "sqlite:///:memory:",  # In-memory DB
    })
    return app

@pytest.fixture
def client(app):
    """A test client for the app."""
    return app.test_client()

@pytest.fixture
def runner(app):
    """A test runner for CLI commands."""
    return app.test_cli_runner()

def test_edit_nonexistent_todo_redirects_to_home(client):
    """Test that /edit/999 → 302 → /"""
    response = client.get('/edit/999')

    # 1. Check status code
    assert response.status_code == 302

    # 2. Check redirect location
    assert response.location.endswith('/')  # or == 'http://localhost/'

    # 3. Follow the redirect and verify final page
    follow = client.get('/edit/999', follow_redirects=True)
    assert follow.status_code == 200
    assert b"My Todos" in follow.data  # from index.html