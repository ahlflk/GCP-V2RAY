FROM alpine:latest

# Install XRay core (supports VLESS WS/gRPC and Trojan)
RUN apk add --no-cache wget unzip curl \
    && wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip \
    && unzip Xray-linux-64.zip \
    && mv xray /usr/local/bin/ \
    && chmod +x /usr/local/bin/xray \
    # Download geo assets for better routing
    && wget https://github.com/XTLS/Xray-core/releases/latest/download/geoip.dat -O /usr/local/share/xray/geoip.dat \
    && wget https://github.com/XTLS/Xray-core/releases/latest/download/geosite.dat -O /usr/local/share/xray/geosite.dat \
    && rm -rf Xray-linux-64.zip LICENSE \
    && apk del wget unzip

# Copy config (single multi-protocol config)
COPY config.json /etc/xray/config.json

# Expose port for Cloud Run
EXPOSE 8080

# Health check for Cloud Run (Use curl to test HTTP response)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s CMD curl -f http://localhost:8080/ || exit 1

# Run XRay
CMD ["xray", "run", "-c", "/etc/xray/config.json"]