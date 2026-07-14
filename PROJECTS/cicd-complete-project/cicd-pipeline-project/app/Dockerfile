# Dockerfile
# CodeBuild reads this and builds the Docker image
# Image gets pushed to ECR
# CodeDeploy pulls it on EC2 and runs the container

FROM python:3.12-slim

# Set working directory inside container
WORKDIR /app

# Copy requirements first (Docker layer caching)
# If requirements.txt unchanged, pip install layer is cached
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Set environment variable for version tracking
ARG APP_VERSION=1.0.0
ENV APP_VERSION=$APP_VERSION

# Expose Flask port
EXPOSE 5000

# Run Flask app
# Using python directly for simplicity
# In production use gunicorn: gunicorn -w 4 -b 0.0.0.0:5000 app:app
CMD ["python", "app.py"]
