FROM python:3.11-slim

WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy agent code
COPY agent.py .

# Expose port
EXPOSE 8090

# Run the agent
CMD ["uvicorn", "agent:a2a_app", "--host", "0.0.0.0", "--port", "8090"]
