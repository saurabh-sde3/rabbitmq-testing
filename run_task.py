from tasks import add

result = add.delay(3, 7)
print("Task sent. Waiting for result...")
print("Result:", result.get(timeout=10))