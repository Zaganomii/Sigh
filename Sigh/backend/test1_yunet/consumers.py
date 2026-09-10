import asyncio
import json
import logging
from channels.generic.websocket import AsyncWebsocketConsumer
from .face_streamer import FaceStreamer
from asgiref.sync import sync_to_async

logger = logging.getLogger(__name__)

streamer = FaceStreamer()


class VideoStreamConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        logger.info("WebSocket connection attempt")
        await self.accept()
        self.group_name = "video_stream"

        # Latest-frame buffer: only the newest frame is kept per client
        self._latest_frame = None
        self._frame_event = asyncio.Event()
        self._sender_task = asyncio.create_task(self._frame_sender())

        try:
            await self.channel_layer.group_add(self.group_name, self.channel_name)
            if not streamer.running:
                streamer.start()
            logger.info("WebSocket connected successfully")
        except Exception as e:
            logger.error(f"WebSocket connection failed: {e}")
            await self.close()

    async def disconnect(self, close_code):
        if getattr(self, "_sender_task", None):
            self._sender_task.cancel()
        try:
            await self.channel_layer.group_discard(self.group_name, self.channel_name)
            logger.info(f"WebSocket disconnected with code: {close_code}")
        except Exception as e:
            logger.error(f"WebSocket disconnect error: {e}")

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
            message_type = data.get('type')

            if message_type == 'register_face':
                await self.handle_face_registration(data)
            elif message_type == 'set_session':
                await self.handle_set_session(data)
            elif message_type == 'get_sessions':
                await self.handle_get_sessions()
            elif message_type == 'get_session_participants':
                await self.handle_get_session_participants(data)

        except json.JSONDecodeError as e:
            logger.error(f"JSON decode error: {e}")
            await self.send_error("Invalid JSON format")
        except Exception as e:
            logger.error(f"WebSocket receive error: {e}")
            await self.send_error("Internal server error")

    async def handle_face_registration(self, data):
        face_data = data.get('face_data')
        name = data.get('name')
        role = data.get('role')

        if not all([face_data, name, role]):
            await self.send_error("Missing required fields")
            return

        success = await sync_to_async(streamer.register_face)(face_data, name, role)

        await self.send(text_data=json.dumps({
            'type': 'registration_result',
            'success': success,
            'name': name,
            'message': 'Registration successful' if success else 'Registration failed'
        }))

    async def handle_set_session(self, data):
        session_id = data.get('session_id')
        if not session_id:
            await self.send_error("Session ID required")
            return

        try:
            from django.core.exceptions import ValidationError
            from django.db.models import UUIDField

            uuid_field = UUIDField()
            uuid_field.run_validators(session_id)

        except ValidationError:
            await self.send_error("Invalid session ID format")
            return

        success = await sync_to_async(streamer.set_current_session)(session_id)

        await self.send(text_data=json.dumps({
            'type': 'session_set_result',
            'success': success,
            'session_id': session_id,
            'message': 'Session set successfully' if success else 'Failed to set session'
        }))

    async def handle_get_sessions(self):
        try:
            Session = streamer.Session
            sessions = await sync_to_async(list)(
                Session.objects.filter(is_active=True).values('id', 'name', 'description', 'created_at')
            )

            serializable_sessions = []
            for session in sessions:
                serializable_sessions.append({
                    'id': str(session['id']),
                    'name': session['name'],
                    'description': session['description'],
                    'created_at': session['created_at'].isoformat() if session['created_at'] else None
                })

            await self.send(text_data=json.dumps({
                'type': 'sessions_list',
                'sessions': serializable_sessions
            }))
        except Exception as e:
            logger.error(f"Error getting sessions: {e}")
            await self.send_error("Failed to get sessions")

    async def handle_get_session_participants(self, data):
        session_id = data.get('session_id')
        if not session_id:
            await self.send_error("Session ID required")
            return

        participants = await sync_to_async(streamer.get_session_participants)(session_id)

        await self.send(text_data=json.dumps({
            'type': 'session_participants',
            'session_id': session_id,
            'participants': participants
        }))

    async def send_error(self, message):
        await self.send(text_data=json.dumps({
            'type': 'error',
            'message': message
        }))

    async def send_frame(self, event):
        """Buffer the newest frame and wake the sender; older frames are dropped."""
        self._latest_frame = event["bytes_data"]
        self._frame_event.set()

    async def _frame_sender(self):
        """Send only the most recent frame, coalescing bursts instead of queueing."""
        try:
            while True:
                await self._frame_event.wait()
                self._frame_event.clear()
                frame = self._latest_frame
                self._latest_frame = None
                if frame is not None:
                    await self.send(bytes_data=frame)
        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error(f"Frame sender stopped: {e}")
            await self.close()
