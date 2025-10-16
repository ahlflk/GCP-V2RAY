# Use Debian slim as base image
FROM debian:bullseye-slim

# Set working directory
WORKDIR /app

# Install necessary tools and dependencies
RUN apt-get update -qq -y && \
    apt-get install -qq -y unzip curl && \
    rm -rf /var/lib/apt/lists/*

# Download and install Xray
RUN curl -L -o Xray-linux-64.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip && \
    unzip -q Xray-linux-64.zip && \
    rm -f Xray-linux-64.zip && \
    chmod +x /app/xray && \
    mkdir -p /etc/xray

# Copy configuration files
COPY config.json /etc/xray/config.json

# Expose ports
EXPOSE 8080

# Run Xray
CMD ["xray", "run", "-config", "/etc/xray/config.json"]