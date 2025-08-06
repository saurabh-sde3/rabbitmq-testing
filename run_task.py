from celery import Celery

# Connecting to RabbitMQ running on the same machine (localhost)
app = Celery('tasks', broker='amqp://guest:guest@localhost:5672//', backend='rpc://')

@app.task
def add(x, y):
    return x + y