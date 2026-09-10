"""
URL configuration for sigh_backend_yunet project.
"""

from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('test1_yunet.urls')),
]
