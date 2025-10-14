# Use a lean base image (Alpine is lightweight)
FROM alpine:3.18 as builder

# Install necessary packages
RUN apk add --no-cache curl unzip

# Download Xray-core (You can adjust the version if needed)
# Cloud Run runs on linux/amd64 (linux-64) architecture
ENV XRAY_VERSION 1.8.10
ENV XRAY_URL "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip"

RUN curl -L -o xray.zip ${XRAY_URL} \
    && unzip xray.zip -d /usr/local/bin \
    && rm xray.zip

# Final minimal image
FROM alpine:3.18

# Copy Xray binary and config
COPY --from=builder /usr/local/bin/xray /usr/local/bin/xray
COPY config.json /etc/xray/config.json

# Cloud Run injects the PORT env variable; we set a default 8080.
ENV PORT 8080

# Xray Command: Run Xray and listen on 0.0.0.0 for the specified port (8080).
# Cloud Run Ingress will forward 443 traffic to this 8080 port.
CMD ["/usr/local/bin/xray", "-config", "/etc/xray/config.json", "-address", "0.0.0.0"]
