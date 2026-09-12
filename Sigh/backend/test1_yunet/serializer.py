from rest_framework import serializers
from .models import Session, Person, SessionPerson, AttendanceLog

class PersonSerializer(serializers.ModelSerializer):
    class Meta:
        model = Person
        fields = ['id', 'name', 'role', 'created_at']
        read_only_fields = ['id', 'created_at']

class SessionSerializer(serializers.ModelSerializer):
    participant_count = serializers.SerializerMethodField()
    weekly_schedule = serializers.ReadOnlyField(default=None)
    
    class Meta:
        model = Session
        fields = [
            'id', 'name', 'description', 'is_active', 'created_at',
            'participant_count', 'weekly_day', 'weekly_start_time',
            'weekly_end_time', 'weekly_schedule'
        ]
        read_only_fields = ['id', 'created_at']
    
    def get_participant_count(self, obj):
        return obj.participants.count()

class SessionPersonSerializer(serializers.ModelSerializer):
    person_name = serializers.CharField(source='person.name', read_only=True)
    session_name = serializers.CharField(source='session.name', read_only=True)
    
    class Meta:
        model = SessionPerson
        fields = ['id', 'session', 'person', 'person_name', 'session_name', 'is_present', 'last_seen']

class AttendanceLogSerializer(serializers.ModelSerializer):
    person_name = serializers.CharField(source='person.name', read_only=True)
    session_name = serializers.CharField(source='session.name', read_only=True)
    
    class Meta:
        model = AttendanceLog
        fields = ['id', 'session', 'person', 'person_name', 'session_name', 'timestamp']
