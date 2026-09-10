from django.urls import re_path
from test1_yunet.consumers import VideoStreamConsumer

websocket_urlpatterns = [
    re_path(r"ws/stream/$", VideoStreamConsumer.as_asgi()),
]
