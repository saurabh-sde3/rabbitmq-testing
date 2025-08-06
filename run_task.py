#!/usr/bin/env python3
"""
RabbitMQ Testing Application - Task Runner

This script demonstrates how to send tasks to the Celery worker
and retrieve results.
"""

import time
import sys
from tasks import add, multiply, health_check

def main():
    """Main function to run various tasks."""
    print("🚀 Starting RabbitMQ Testing Application")
    print("=" * 50)
    
    try:
        # Test 1: Health check
        print("\n1. Running health check...")
        health_result = health_check.delay()
        print(f"Health check result: {health_result.get(timeout=10)}")
        
        # Test 2: Addition task
        print("\n2. Running addition task (3 + 7)...")
        add_result = add.delay(3, 7)
        print("Task sent. Waiting for result...")
        result = add_result.get(timeout=10)
        print(f"Addition result: {result}")
        
        # Test 3: Multiplication task
        print("\n3. Running multiplication task (4 * 5)...")
        mult_result = multiply.delay(4, 5)
        print("Task sent. Waiting for result...")
        result = mult_result.get(timeout=10)
        print(f"Multiplication result: {result}")
        
        # Test 4: Multiple tasks
        print("\n4. Running multiple tasks simultaneously...")
        tasks = [
            add.delay(i, i + 1) for i in range(5)
        ]
        
        print("Tasks sent. Collecting results...")
        for i, task in enumerate(tasks):
            result = task.get(timeout=10)
            print(f"Task {i + 1} result: {result}")
        
        print("\n✅ All tests completed successfully!")
        
    except Exception as e:
        print(f"\n❌ Error occurred: {e}")
        print("Make sure RabbitMQ server and Celery worker are running.")
        sys.exit(1)

if __name__ == "__main__":
    main()