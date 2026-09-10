from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'sessions', views.SessionViewSet)
router.register(r'people', views.PersonViewSet)
router.register(r'session-people', views.SessionPersonViewSet)
router.register(r'attendance-logs', views.AttendanceLogViewSet)

urlpatterns = [
    path('api/', include(router.urls)),
    path('api/dashboard/stats/', views.DashboardStatsView.as_view(), name='dashboard-stats'),
    path('api/sessions/<uuid:session_id>/participants/', views.SessionParticipantsView.as_view(), name='session-participants'),
    path('api/sessions/<uuid:session_id>/participants/<uuid:person_id>/', views.RemoveSessionParticipantView.as_view(), name='remove-session-participant'),
]
