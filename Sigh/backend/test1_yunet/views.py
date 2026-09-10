from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone
from django.shortcuts import get_object_or_404
from .models import Session, Person, SessionPerson, AttendanceLog
from .serializer import *

class SessionViewSet(viewsets.ModelViewSet):
    queryset = Session.objects.all().order_by('-created_at')
    serializer_class = SessionSerializer
    
    def perform_destroy(self, instance):
        # Instead of actually deleting, we can deactivate
        instance.is_active = False
        instance.save()

class PersonViewSet(viewsets.ModelViewSet):
    queryset = Person.objects.all().order_by('-created_at')
    serializer_class = PersonSerializer

class SessionPersonViewSet(viewsets.ModelViewSet):
    queryset = SessionPerson.objects.all()
    serializer_class = SessionPersonSerializer
    
    @action(detail=True, methods=['post'])
    def mark_present(self, request, pk=None):
        session_person = self.get_object()
        session_person.is_present = True
        session_person.last_seen = timezone.now()
        session_person.save()
        
        # Create attendance log
        AttendanceLog.objects.create(
            session=session_person.session,
            person=session_person.person
        )
        
        return Response({'status': 'marked present'})
    
    @action(detail=True, methods=['post'])
    def mark_absent(self, request, pk=None):
        session_person = self.get_object()
        session_person.is_present = False
        session_person.save()
        return Response({'status': 'marked absent'})

class AttendanceLogViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = AttendanceLog.objects.all().order_by('-timestamp')
    serializer_class = AttendanceLogSerializer

# Additional views for dashboard
from django.db.models import Count, Q

class DashboardStatsView(APIView):
    def get(self, request):
        total_sessions = Session.objects.filter(is_active=True).count()
        total_people = Person.objects.count()
        active_sessions = Session.objects.filter(is_active=True).count()
        
        # Today's attendance
        today = timezone.now().date()
        today_attendance = AttendanceLog.objects.filter(
            timestamp__date=today
        ).count()
        
        stats = {
            'total_sessions': total_sessions,
            'total_people': total_people,
            'active_sessions': active_sessions,
            'today_attendance': today_attendance,
        }
        
        return Response(stats)

# NEW: Session Participants Management Views
class SessionParticipantsView(APIView):
    def get(self, request, session_id):
        try:
            session = Session.objects.get(id=session_id)
            participants = SessionPerson.objects.filter(session=session)
            serializer = SessionPersonSerializer(participants, many=True)
            return Response(serializer.data)
        except Session.DoesNotExist:
            return Response({'error': 'Session not found'}, status=status.HTTP_404_NOT_FOUND)

    def post(self, request, session_id):
        try:
            session = Session.objects.get(id=session_id)
            person_id = request.data.get('person_id')
            
            try:
                person = Person.objects.get(id=person_id)
            except Person.DoesNotExist:
                return Response({'error': 'Person not found'}, status=status.HTTP_404_NOT_FOUND)
            
            # Check if person is already in session
            if SessionPerson.objects.filter(session=session, person=person).exists():
                return Response({'error': 'Person already in session'}, status=status.HTTP_400_BAD_REQUEST)
            
            session_person = SessionPerson.objects.create(
                session=session,
                person=person,
                is_present=False
            )
            
            serializer = SessionPersonSerializer(session_person)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
            
        except Session.DoesNotExist:
            return Response({'error': 'Session not found'}, status=status.HTTP_404_NOT_FOUND)

class RemoveSessionParticipantView(APIView):
    def delete(self, request, session_id, person_id):
        try:
            session_person = SessionPerson.objects.get(
                session_id=session_id, 
                person_id=person_id
            )
            session_person.delete()
            return Response({'status': 'participant removed'}, status=status.HTTP_204_NO_CONTENT)
        except SessionPerson.DoesNotExist:
            return Response({'error': 'Participant not found in session'}, status=status.HTTP_404_NOT_FOUND)
