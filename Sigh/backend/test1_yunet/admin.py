from django.contrib import admin
from .models import Session, Person, SessionPerson, AttendanceLog


@admin.register(Session)
class SessionAdmin(admin.ModelAdmin):
    list_display = ['name', 'created_at', 'is_active']
    list_filter = ['is_active', 'created_at']
    search_fields = ['name', 'description']


@admin.register(Person)
class PersonAdmin(admin.ModelAdmin):
    list_display = ['name', 'role', 'created_at']
    list_filter = ['role', 'created_at']
    search_fields = ['name']


@admin.register(SessionPerson)
class SessionPersonAdmin(admin.ModelAdmin):
    list_display = ['session', 'person', 'is_present', 'last_seen']
    list_filter = ['is_present', 'session']
    search_fields = ['person__name']


@admin.register(AttendanceLog)
class AttendanceLogAdmin(admin.ModelAdmin):
    list_display = ['session', 'person', 'timestamp']
    list_filter = ['session', 'timestamp']
    search_fields = ['person__name']
