from django.db import models
import uuid


class Session(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name


class Person(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100, unique=True)
    role = models.CharField(max_length=100)
    face_encoding = models.BinaryField()  # Store face encoding as binary (128-D vector)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} ({self.role})"


class SessionPerson(models.Model):
    session = models.ForeignKey(Session, on_delete=models.CASCADE, related_name='participants')
    person = models.ForeignKey(Person, on_delete=models.CASCADE)
    is_present = models.BooleanField(default=False)
    last_seen = models.DateTimeField(null=True, blank=True)

    class Meta:
        unique_together = ['session', 'person']

    def __str__(self):
        return f"{self.person.name} in {self.session.name}"


class AttendanceLog(models.Model):
    session = models.ForeignKey(Session, on_delete=models.CASCADE)
    person = models.ForeignKey(Person, on_delete=models.CASCADE)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ['session', 'person', 'timestamp']

    def __str__(self):
        return f"{self.person.name} at {self.timestamp}"
