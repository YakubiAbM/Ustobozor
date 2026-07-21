"""
Rate limiter на базе slowapi (по IP).
Используется в main и auth_routes для ограничения запросов к /auth/*, /chat/*, /products/search.
"""

try:
    from slowapi import Limiter
    from slowapi.util import get_remote_address
    limiter = Limiter(key_func=get_remote_address)
except ImportError:
    limiter = None
