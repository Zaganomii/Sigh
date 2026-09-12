from django.db import models
import uuid


class Session(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)
    
    # Weekly schedule (optional)
    weekly_day = models.IntegerField(
        choices=[
            (0, 'Monday'),
            (1, 'Tuesday'),
            (2, 'Wednesday'),
            (3, 'Thursday'),
            (4, 'Friday'),
            (5, 'Saturday'),
            (6, 'Sunday'),
        ],
        null=True,
        blank=True,
        help_text='Day of week for recurring session (0=Monday, 6=Sunday)'
    )
    weekly_start_time = models.TimeField(
        null=True,
        blank=True,
        help_text='Start time for weekly session (e.g. 09:00)'
    )
    weekly_end_time = models.TimeField(
        null=True,
        blank=True,
        help_text='End time for weekly session (e.g. 10:00)'
    )

    def __str__(self):
        return self.name

    @property
    def weekly_schedule(self):
        """Return a human-readable weekly schedule string, or None if not set."""
        if self.weekly_day is None or self.weekly_start_time is None:
            return None
        days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        day_name = days[self.weekly_day]
        start = self.weekly_start_time.strftime('%I:%M %p')
        if self.weekly_end_time:
            end = self.weekly_end_time.strftime('%I:%M %p')
            return f'Every {day_name} from {start} to {end}'
        return f'Every {day_name} at {start}'


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
