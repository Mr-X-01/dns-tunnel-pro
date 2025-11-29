FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    dnsutils \
    net-tools \
    curl \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Create necessary directories
RUN mkdir -p database logs ssl config

# Expose ports
EXPOSE 53/udp
EXPOSE 8443

# Run the server
CMD ["python3", "main.py"]
