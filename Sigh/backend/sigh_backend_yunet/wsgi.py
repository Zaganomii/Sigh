"""
WSGI config for sigh_backend_yunet project.
"""

import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "sigh_backend_yunet.settings")

application = get_wsgi_application()
