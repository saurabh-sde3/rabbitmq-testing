import os
from celery import Celery

# Configuration with environment variables for flexibility
BROKER_URL = os.getenv('CELERY_BROKER_URL', 'amqp://guest:guest@localhost:5672//')
BACKEND_URL = os.getenv('CELERY_RESULT_BACKEND', 'rpc://')

# Connecting to RabbitMQ
app = Celery('tasks', broker=BROKER_URL, backend=BACKEND_URL)

# Celery configuration
app.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    task_track_started=True,
    task_time_limit=30 * 60,  # 30 minutes
    task_soft_time_limit=25 * 60,  # 25 minutes
    worker_prefetch_multiplier=1,
    worker_max_tasks_per_child=1000,
)

@app.task(bind=True)
def add(self, x, y):
    """Add two numbers together."""
    try:
        result = x + y
        self.update_state(state='PROGRESS', meta={'current': 50, 'total': 100})
        return {'result': result, 'status': 'completed'}
    except Exception as exc:
        self.update_state(
            state='FAILURE',
            meta={'current': 0, 'total': 100, 'error': str(exc)}
        )
        raise

@app.task(bind=True)
def multiply(self, x, y):
    """Multiply two numbers."""
    try:
        result = x * y
        return {'result': result, 'status': 'completed'}
    except Exception as exc:
        self.update_state(
            state='FAILURE',
            meta={'error': str(exc)}
        )
        raise

@app.task(bind=True)
def health_check(self):
    """Health check task for monitoring."""
    return {'status': 'healthy', 'message': 'Celery worker is running'}

if __name__ == '__main__':
    app.start()