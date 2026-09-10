"""
ASGI config for sigh_backend_yunet project.

Uses YuNet + MobileFaceNet for face detection and recognition.
"""

import os
from channels.routing import ProtocolTypeRouter, URLRouter
from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "sigh_backend_yunet.settings")

django_asgi_app = get_asgi_application()
import sigh_backend_yunet.routing

application = ProtocolTypeRouter({
    "http": django_asgi_app,
    "websocket": URLRouter(sigh_backend_yunet.routing.websocket_urlpatterns),
})
