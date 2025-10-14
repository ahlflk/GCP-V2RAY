#!/bin/bash

set -euo pipefail

# Enhanced Modern Color Scheme
RED='\033[1;31m'
GREEN='\033[1;32m'
LIGHT_GREEN='\033[0;92m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

# Logging functions (unchanged)
log() {
    echo -e "${GREEN}✅ [$(date +'%Y-%m-%d %H:%M:%S')] ${NC}$1"
}

warn() {
    echo -e "${YELLOW}⚠️ [WARNING]${NC} $1"
}

error() {
    echo -e "${RED}❌ [ERROR]${NC} $1"
    exit 1
}

info() {
    local label="$1"
    local value="$2"
    echo -e "${LIGHT_GREEN}🎯 Selected ${label}: ${CYAN}${value}${NC}${LIGHT_GREEN}"
    echo -e "─────────────────────────────────────────────${NC}"
}

success() {
    echo -e "${GREEN}✅ [SUCCESS]${NC} $1"
}

print_header() {
    local title="$1"
    local padded_title=$(printf "%-58s" "$title")
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  ${YELLOW}${padded_title}${CYAN} ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Generate UUID function (unchanged)
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen
    else
        python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || echo "3675119c-14fc-46a4-b5f3-9a2c91a7d802"
    fi
}

# Protocol selection (Modified warning for Trojan)
select_protocol() {
    print_header "🔒 Xray Protocol Selection"
    echo -e "1. VLESS (WebSocket + TLS) - ${GREEN}(Cloud Run Recommended / Default)${NC}"
    echo -e "2. VLESS (gRPC + TLS) - ${BLUE}(Cloud Run Recommended)${NC}"
    echo -e "3. Trojan (TLS) - ${RED}WARNING: Raw TCP/TLS is NOT supported by Cloud Run. May FAIL unless Trojan-WS/gRPC is used.${NC}"
    echo

    while true; do
        read -p "Select protocol (default 1): " protocol_choice
        protocol_choice=${protocol_choice:-1}
        case $protocol_choice in
            1) PROTOCOL="vless-ws"; break ;;
            2) PROTOCOL="vless-grpc"; break ;;
            3) PROTOCOL="trojan"; warn "Trojan selected: Please ensure your config/client uses an HTTP-based transport (WS/gRPC) if deployment fails."; break ;;
            *) echo "Invalid selection. Please enter 1-3." ;;
        esac
    done

    info "Protocol" "$PROTOCOL"
}

# CPU selection (unchanged)
select_cpu() {
    print_header "💻 CPU Configuration"
    echo -e "1. 1  CPU Core"
    echo -e "2. 2  CPU Cores ${GREEN}(Default)${NC}"
    echo -e "3. 4  CPU Cores"
    echo -e "4. 8  CPU Cores"
    echo -e "5. 16 CPU Cores (Warning: Cloud Run standard max is 8 vCPU; quota request may be needed)"
    echo

    while true; do
        read -p "Select CPU cores (default 2): " cpu_choice
        cpu_choice=${cpu_choice:-2}
        case $cpu_choice in
            1) CPU="1"; break ;;
            2) CPU="2"; break ;;
            3) CPU="4"; break ;;
            4) CPU="8"; break ;;
            5) CPU="16"; warn "16 cores selected: Ensure your GCP quota allows >8 vCPU, or deploy will fail."; break ;;
            *) echo "Invalid selection. Please enter 1-5." ;;
        esac
    done

    info "CPU" "$CPU core(s)"
}

# Memory selection (unchanged)
select_memory() {
    print_header "💾 Memory Configuration"
    echo -e "1. 512Mi"
    echo -e "2. 1Gi"
    echo -e "3. 2Gi${GREEN}(Default)${NC}"
    echo -e "4. 4Gi"
    echo -e "5. 8Gi"
    echo -e "6. 16Gi"
    echo -e "7. 32Gi (Max)"
    echo

    while true; do
        read -p "Select memory (default 3): " memory_choice
        memory_choice=${memory_choice:-3}
        case $memory_choice in
            1) MEMORY="512Mi"; break ;;
            2) MEMORY="1Gi"; break ;;
            3) MEMORY="2Gi"; break ;;
            4) MEMORY="4Gi"; break ;;
            5) MEMORY="8Gi"; break ;;
            6) MEMORY="16Gi"; break ;;
            7) MEMORY="32Gi"; break ;;
            *) echo "Invalid selection. Please enter 1-7." ;;
        esac
    done

    validate_memory_config
    info "Memory" "$MEMORY"
}

# validate_memory_config (unchanged)
validate_memory_config() {
    local cpu_num=$CPU
    local memory_num=$(echo $MEMORY | sed 's/[^0-9]*//g')
    local memory_unit=$(echo $MEMORY | sed 's/[0-9]*//g' | sed 's/i//g')

    if [[ "$memory_unit" == "G" ]]; then
        memory_num=$((memory_num * 1024))
    elif [[ "$memory_unit" == "M" ]]; then
        memory_num=$memory_num
    fi

    local min_memory=128  # MiB
    local max_memory=32768  # MiB (32Gi)
    case $cpu_num in
        1) min_memory=128; max_memory=2048 ;;
        2) min_memory=128; max_memory=4096 ;;
        4) min_memory=512; max_memory=8192 ;;
        8|16) min_memory=1024; max_memory=32768 ;;
    esac

    if [[ $memory_num -lt $min_memory ]]; then
        warn "Memory too low for $CPU CPU. Min: ${min_memory}Mi"
        read -p "Continue? (y/n): " confirm
        [[ $confirm =~ [Yy] ]] || select_memory
    elif [[ $memory_num -gt $max_memory ]]; then
        warn "Memory too high for $CPU CPU. Max: $((max_memory / 1024))Gi"
        read -p "Continue? (y/n): " confirm
        [[ $confirm =~ [Yy] ]] || select_memory
    fi
}

# Region selection (unchanged)
select_region() {
    print_header "🌍 Region Selection"
    echo -e "1.  🇺🇸 us-central1 (Council Bluffs, Iowa, North America) ${GREEN}(Default)${NC}"
    echo -e "2.  🇺🇸 us-east1 (Moncks Corner, South Carolina, North America)"
    echo -e "3.  🇺🇸 us-south1 (Dallas, Texas, North America)"
    echo -e "4.  🇺🇸 southamerica-west1 (Santiago, Chile, South America)"
    echo -e "5.  🇺🇸 us-west1 (The Dalles, Oregon, North America)"
    echo -e "6.  🇨🇦 northamerica-northeast2 (Toronto, Ontario, North America)"
    echo -e "7.  🇸🇬 asia-southeast1 (Jurong West, Singapore)"
    echo -e "8.  🇯🇵 asia-northeast1 (Tokyo, Japan)"
    echo -e "9.  🇹🇼 asia-east1 (Changhua County, Taiwan)"
    echo -e "10. 🇭🇰 asia-east2 (Hong Kong)"
    echo -e "11. 🇮🇳 asia-south1 (Mumbai, India)"
    echo -e "12. 🇮🇩 asia-southeast2 (Jakarta, Indonesia)"
    echo

    while true; do
        read -p "Select region (default 1): " region_choice
        region_choice=${region_choice:-1}
        case $region_choice in
            1) REGION="us-central1"; break ;;
            2) REGION="us-east1"; break ;;
            3) REGION="us-south1"; break ;;
            4) REGION="southamerica-west1"; break ;;
            5) REGION="us-west1"; break ;;
            6) REGION="northamerica-northeast2"; break ;;
            7) REGION="asia-southeast1"; break ;;
            8) REGION="asia-northeast1"; break ;;
            9) REGION="asia-east1"; break ;;
            10) REGION="asia-east2"; break ;;
            11) REGION="asia-south1"; break ;;
            12) REGION="asia-southeast2"; break ;;
            *) echo "Invalid selection. Please enter 1-12." ;;
        esac
    done

    info "Region" "$REGION"
}

# Telegram selection (unchanged)
select_telegram_destination() {
    print_header "📱 Telegram Notification Options"
    echo -e "1. Send to Channel only"
    echo -e "2. Send to Bot private message only"
    echo -e "3. Send to both Channel and Bot"
    echo -e "4. Send to a Group"
    echo -e "5. Don't send to Telegram ${GREEN}(Default)${NC}"
    echo

    while true; do
        read -p "Select destination (default 5): " telegram_choice
        telegram_choice=${telegram_choice:-5}
        case $telegram_choice in
            1)
                TELEGRAM_DESTINATION="channel"
                while true; do
                    read -p "Enter Telegram Channel ID: " TELEGRAM_CHANNEL_ID
                    if validate_channel_id "$TELEGRAM_CHANNEL_ID"; then break; fi
                done
                break
                ;;
            2)
                TELEGRAM_DESTINATION="bot"
                while true; do
                    read -p "Enter your Chat ID: " TELEGRAM_CHAT_ID
                    if validate_chat_id "$TELEGRAM_CHAT_ID"; then break; fi
                done
                break
                ;;
            3)
                TELEGRAM_DESTINATION="both"
                while true; do
                    read -p "Enter Telegram Channel ID: " TELEGRAM_CHANNEL_ID
                    if validate_channel_id "$TELEGRAM_CHANNEL_ID"; then break; fi
                done
                while true; do
                    read -p "Enter your Chat ID: " TELEGRAM_CHAT_ID
                    if validate_chat_id "$TELEGRAM_CHAT_ID"; then break; fi
                done
                break
                ;;
            4)
                TELEGRAM_DESTINATION="group"
                while true; do
                    read -p "Enter Telegram Group ID: " TELEGRAM_GROUP_ID
                    if validate_chat_id "$TELEGRAM_GROUP_ID"; then
                        TELEGRAM_CHAT_ID="$TELEGRAM_GROUP_ID"
                        break
                    fi
                done
                break
                ;;
            5)
                TELEGRAM_DESTINATION="none"
                break
                ;;
            *) echo "Invalid selection. Please enter 1-5." ;;
        esac
    done

    info "Telegram Destination" "$TELEGRAM_DESTINATION"
}

# Service Configuration (unchanged)
get_user_input() {
    print_header "⚙️ Service Configuration"

    # Service Name options
    echo -e "${YELLOW}⚙️ Service Name Options:${NC}"
    echo -e "1. Use default: gcp-ahlflk ${GREEN}(Default)${NC}"
    echo -e "2. Enter custom name"
    echo
    read -p "Select (1-2, default 1): " name_choice
    name_choice=${name_choice:-1}
    case $name_choice in
        1)
            SERVICE_NAME="gcp-ahlflk"
            info "Service Name" "$SERVICE_NAME"
            ;;
        2)
            read -p "Enter service name: " SERVICE_NAME
            SERVICE_NAME=${SERVICE_NAME:-"gcp-ahlflk"}
            if validate_service_name "$SERVICE_NAME"; then
                info "Service Name" "$SERVICE_NAME"
            else
                SERVICE_NAME="gcp-ahlflk"
                info "Service Name" "$SERVICE_NAME (default)"
            fi
            ;;
        *) SERVICE_NAME="gcp-ahlflk"; info "Service Name" "$SERVICE_NAME" ;;
    esac

    # UUID options
    echo -e "${YELLOW}⚙️ UUID Options:${NC}"
    echo -e "1. Generate new UUID"
    echo -e "2. Enter custom UUID"
    echo -e "3. Use default: 3675119c-14fc-46a4-b5f3-9a2c91a7d802 ${GREEN}(Default)${NC}"
    echo
    read -p "Select (1-3, default 3): " uuid_choice
    uuid_choice=${uuid_choice:-3}
    case $uuid_choice in
        1)
            UUID=$(generate_uuid)
            info "UUID" "$UUID"
            ;;
        2)
            read -p "Enter UUID: " UUID
            UUID=${UUID:-"3675119c-14fc-46a4-b5f3-9a2c91a7d802"}
            if validate_uuid "$UUID"; then
                info "UUID" "$UUID"
            else
                UUID="3675119c-14fc-46a4-b5f3-9a2c91a7d802"
                info "UUID" "$UUID (default)"
            fi
            ;;
        3)
            UUID="3675119c-14fc-46a4-b5f3-9a2c91a7d802"
            info "UUID" "$UUID"
            ;;
        *) UUID="3675119c-14fc-46a4-b5f3-9a2c91a7d802"; info "UUID" "$UUID" ;;
    esac

    # Host Domain options
    echo -e "${YELLOW}⚙️ Host Domain Options:${NC}"
    echo -e "1. Use default: m.googleapis.com ${GREEN}(Default)${NC}"
    echo -e "2. Enter custom domain"
    echo
    read -p "Select (1-2, default 1): " domain_choice
    domain_choice=${domain_choice:-1}
    case $domain_choice in
        1)
            HOST_DOMAIN="m.googleapis.com"
            info "Host Domain" "$HOST_DOMAIN"
            ;;
        2)
            read -p "Enter host domain: " HOST_DOMAIN
            HOST_DOMAIN=${HOST_DOMAIN:-"m.googleapis.com"}
            info "Host Domain" "$HOST_DOMAIN"
            ;;
        *) HOST_DOMAIN="m.googleapis.com"; info "Host Domain" "$HOST_DOMAIN" ;;
    esac

    # Telegram token if needed
    if [[ "$TELEGRAM_DESTINATION" != "none" ]]; then
        while true; do
            read -p "Enter Telegram Bot Token: " TELEGRAM_BOT_TOKEN
            if validate_bot_token "$TELEGRAM_BOT_TOKEN"; then
                info "Bot Token" "configured"
                break
            fi
        done
    fi
}

# Config summary (unchanged)
show_config_summary() {
    print_header "📋 Configuration Summary"
    echo -e "${CYAN}Project ID:    $(gcloud config get-value project)${NC}"
    echo -e "${CYAN}Protocol:      $PROTOCOL${NC}"
    if [[ "$PROTOCOL" == "trojan" ]]; then
        warn "Trojan: Raw TCP/TLS is NOT supported by Cloud Run. Use Trojan-WS/gRPC for reliability."
    fi
    echo -e "${CYAN}Region:        $REGION${NC}"
    echo -e "${CYAN}Service Name:  $SERVICE_NAME${NC}"
    echo -e "${CYAN}Host Domain:   $HOST_DOMAIN${NC}"
    echo -e "${CYAN}UUID:          $UUID${NC}"
    echo -e "${CYAN}CPU:           $CPU core(s)${NC}"
    if [[ $CPU -gt 8 ]]; then
        warn "CPU >8 cores: Standard Cloud Run limit is 8 vCPU. Request quota increase if needed."
    fi
    echo -e "${CYAN}Memory:        $MEMORY${NC}"

    if [[ "$TELEGRAM_DESTINATION" != "none" ]]; then
        echo -e "${CYAN}Bot Token:     ${TELEGRAM_BOT_TOKEN:0:8}...${NC}"
        echo -e "${CYAN}Destination:   $TELEGRAM_DESTINATION${NC}"
        if [[ "$TELEGRAM_DESTINATION" == "channel" || "$TELEGRAM_DESTINATION" == "both" ]]; then
            echo -e "${CYAN}Channel ID:    $TELEGRAM_CHANNEL_ID${NC}"
        fi
        if [[ "$TELEGRAM_DESTINATION" == "bot" || "$TELEGRAM_DESTINATION" == "both" || "$TELEGRAM_DESTINATION" == "group" ]]; then
            echo -e "${CYAN}Chat/Group ID: $TELEGRAM_CHAT_ID${NC}"
        fi
    else
        echo -e "${CYAN}Telegram:      Disabled${NC}"
    fi
    echo

    while true; do
        read -p "Proceed with deployment? (y/n): " confirm
        case $confirm in 
            [Yy]*) break ;;
            [Nn]*) 
                echo -e "${YELLOW}Deployment cancelled by user.${NC}"
                log "Script exited successfully."
                exit 0 
                ;;
            * ) echo "Please answer y or n." ;;
        esac
    done
}

# Validation functions (unchanged)
validate_service_name() {
    if [[ ! $1 =~ ^[a-zA-Z0-9-]+$ ]]; then
        error "Service name must be alphanumeric with hyphens only: $1"
        return 1
    fi
    return 0
}

validate_uuid() {
    local uuid_pattern='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    if [[ ! $1 =~ $uuid_pattern ]]; then
        error "Invalid UUID format: $1"
        return 1
    fi
    return 0
}

validate_bot_token() {
    local token_pattern='^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$'
    if [[ ! $1 =~ $token_pattern ]]; then
        error "Invalid Telegram Bot Token format"
        return 1
    fi
    return 0
}

validate_channel_id() {
    if [[ ! $1 =~ ^-?[0-9]+$ ]]; then
        error "Invalid Channel ID format"
        return 1
    fi
    return 0
}

validate_chat_id() {
    if [[ ! $1 =~ ^-?[0-9]+$ ]]; then
        error "Invalid Chat ID format"
        return 1
    fi
    return 0
}

# Prerequisites (unchanged)
validate_prerequisites() {
    log "Validating prerequisites..."
    if ! command -v gcloud &> /dev/null; then
        error "gcloud CLI not installed. Install from: https://cloud.google.com/sdk/docs/install"
    fi
    if ! command -v git &> /dev/null; then
        error "git not installed. Install git first."
    fi
    local PROJECT_ID=$(gcloud config get-value project)
    if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
        error "No GCP project set. Run: gcloud config set project YOUR_PROJECT_ID"
    fi
}

# Cleanup (unchanged)
cleanup() {
    log "Cleaning up temporary files..."
    [[ -d "vpn-cloudrun-deploy" ]] && rm -rf vpn-cloudrun-deploy
}

# Update config with UUID and multiple Trojan passwords
update_config() {
    local num_passes=${1:-1}
    local passwords=()

    # Generate passwords for Trojan
    if [[ "$PROTOCOL" == "trojan" ]]; then
        echo "Generating $num_passes passwords for Trojan..."
        for ((i=1; i<=num_passes; i++)); do
            local pass=$(generate_uuid)
            passwords+=("$pass")
            echo "Password $i: $pass"
        done
        # Trojan uses 'password' field as string/array.
        # We replace the placeholder in config.json
        
        # NOTE: The current config.json template uses a single placeholder. 
        # For simplicity and to match the template, we'll use a single UUID for Trojan as well
        # to ensure it works with the shared config file.
        warn "Trojan multi-password feature disabled for shared config template. Using single UUID."
        
        sed -i "s/\"YOUR_UUID_HERE\"/\"$UUID\"/g" config.json
        ALL_PASSWORDS="$UUID"

    else
        # Single UUID for VLESS
        sed -i "s/\"YOUR_UUID_HERE\"/\"$UUID\"/g" config.json
        ALL_PASSWORDS="$UUID"
    fi

    # Update path/serviceName for all protocols
    sed -i "s/\"YOUR_WS_PATH\"/\"ws\"/g" config.json
    sed -i "s/\"YOUR_GRPC_SERVICE_NAME\"/\"grpc-service\"/g" config.json
    
    info "Config Updated" "With UUID(s): $ALL_PASSWORDS, WS Path: /ws, gRPC Service: grpc-service"
}

# Telegram functions (unchanged)
send_to_telegram() {
    local chat_id="$1" message="$2" retries=3
    for ((i=1; i<=retries; i++)); do
        local response
        response=$(curl -s -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "{
            \"chat_id\": \"${chat_id}\",
            \"text\": \"$message\",
            \"parse_mode\": \"MARKDOWN\",
            \"disable_web_page_preview\": true
        }" "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage")

        local http_code="${response: -3}"
        [[ "$http_code" == "200" ]] && return 0
        warn "Telegram retry $i/$retries failed (HTTP $http_code)"
        sleep 2
    done
    error "Telegram send failed after $retries retries"
    return 1
}

send_deployment_notification() {
    local message="$1" success_count=0
    local target_id
    case $TELEGRAM_DESTINATION in
        "channel")
            target_id="$TELEGRAM_CHANNEL_ID"
            log "Sending to Channel..."
            if send_to_telegram "$target_id" "$message"; then success "✅ Sent to Channel"; ((success_count++)); else error "❌ Failed to Channel"; fi
            ;;
        "bot")
            target_id="$TELEGRAM_CHAT_ID"
            log "Sending to Bot PM..."
            if send_to_telegram "$target_id" "$message"; then success "✅ Sent to Bot PM"; ((success_count++)); else error "❌ Failed to Bot PM"; fi
            ;;
        "group")
            target_id="$TELEGRAM_CHAT_ID"
            log "Sending to Group..."
            if send_to_telegram "$target_id" "$message"; then success "✅ Sent to Group"; ((success_count++)); else error "❌ Failed to Group"; fi
            ;;
        "both")
            if send_to_telegram "$TELEGRAM_CHANNEL_ID" "$message"; then success "✅ Sent to Channel"; ((success_count++)); else error "❌ Failed to Channel"; fi
            if send_to_telegram "$TELEGRAM_CHAT_ID" "$message"; then success "✅ Sent to Bot PM"; ((success_count++)); else error "❌ Failed to Bot PM"; fi
            ;;
        "none") log "Skipping Telegram."; return 0 ;;
    esac
    [[ $success_count -gt 0 ]] && log "Telegram completed ($success_count successful)" || warn "Telegram failed, but deployment succeeded."
}

# Main function (Modified repo cloning part)
main() {
    print_header "🚀 GCP Cloud Run Xray Deployment (Multi-Protocol Edition)"
    info "Welcome" "Deploying multi-protocol VPN on Cloud Run using Xray-core."

    # ... (Selection functions)
    select_protocol
    select_region
    select_cpu
    select_memory
    select_telegram_destination
    get_user_input
    show_config_summary

    local PROJECT_ID=$(gcloud config get-value project)
    log "Starting deployment for Project: $PROJECT_ID"

    validate_prerequisites
    trap cleanup EXIT

    log "Enabling APIs... "
    gcloud services enable cloudbuild.googleapis.com run.googleapis.com iam.googleapis.com --quiet && success "[OK]" || warn "[Some already enabled]"

    # Create temporary directory and files
    local REPO_DIR="vpn-cloudrun-deploy"
    cleanup
    log "Creating deployment directory: $REPO_DIR"
    mkdir -p "$REPO_DIR" || error "Failed to create directory."
    cd "$REPO_DIR"

    # Create Dockerfile and config.json
    log "Generating Dockerfile and config.json..."
    cat << EOF > Dockerfile
# Use a lean base image (Alpine is lightweight)
FROM alpine:3.18 as builder

# Install necessary packages
RUN apk add --no-cache curl unzip

# Download Xray-core (Choose appropriate version/architecture)
ENV XRAY_VERSION 1.8.10
ENV XRAY_URL "https://github.com/XTLS/Xray-core/releases/download/v\${XRAY_VERSION}/Xray-linux-64.zip"

RUN curl -L -o xray.zip \${XRAY_URL} \
    && unzip xray.zip -d /usr/local/bin \
    && rm xray.zip

# Final minimal image
FROM alpine:3.18

# Copy Xray binary and config
COPY --from=builder /usr/local/bin/xray /usr/local/bin/xray
COPY config.json /etc/xray/config.json

# Expose the port Cloud Run assigns (environment variable PORT is automatically set)
# We use 8080 as a common default, but the startup command ensures it uses \$PORT
ENV PORT 8080

# Run Xray using the PORT environment variable
CMD ["/usr/local/bin/xray", "-config", "/etc/xray/config.json", "-address", "0.0.0.0"]
EOF

    cat << EOF > config.json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 8080,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "YOUR_UUID_HERE",
            "flow": ""
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "YOUR_WS_PATH",
          "headers": {
            "Host": "m.googleapis.com"
          }
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "listen": "0.0.0.0",
      "port": 8080,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "YOUR_UUID_HERE",
            "flow": ""
          }
        ],
        "fallbacks": []
      },
      "streamSettings": {
        "network": "grpc",
        "security": "none",
        "grpcSettings": {
          "serviceName": "YOUR_GRPC_SERVICE_NAME",
          "multiMode": true
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF
    success "Configuration files created."

    # Update config with UUID and other parameters
    local num_passes=1
    if [[ "$PROTOCOL" == "trojan" ]]; then
        read -p "How many passwords for Trojan? (default 1 - Single user only): " num_passes_input
        num_passes=${num_passes_input:-1}
    fi
    # NOTE: The config.json template only supports a single UUID/password for simplicity and compatibility.
    update_config "$num_passes"

    log "Building container image... "
    gcloud builds submit --tag "gcr.io/${PROJECT_ID}/multi-vpn-image" --quiet && success "[OK]" || error "[FAILED]"

    log "Deploying to Cloud Run... "
    # Note: Cloud Run automatically maps incoming 443/80 traffic to the container's PORT (8080 in this case)
    gcloud run deploy "$SERVICE_NAME" \
        --image "gcr.io/${PROJECT_ID}/multi-vpn-image" \
        --platform managed \
        --region "$REGION" \
        --allow-unauthenticated \
        --cpu "$CPU" \
        --memory "$MEMORY" \
        --port 8080 \
        --quiet && success "[OK]" || error "[FAILED]"

    local SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region "$REGION" --format 'value(status.url)' --quiet)
    local DOMAIN=$(echo "$SERVICE_URL" | sed 's|https://||')

    # Share link generation (protocol-specific)
    local SHARE_LINK
    local FOOTNOTE="*Client Setup:* Address: \`${DOMAIN}\`, Port: 443, Security: TLS. For WS/gRPC, ensure Transport Mode is set correctly."
    
    case $PROTOCOL in
        "vless-ws")
            SHARE_LINK="vless://${UUID}@${DOMAIN}:443?path=%2Fws&security=tls&encryption=none&host=${HOST_DOMAIN}&type=ws&sni=${DOMAIN}#${SERVICE_NAME}-WS"
            ;;
        "vless-grpc")
            SHARE_LINK="vless://${UUID}@${DOMAIN}:443?type=grpc&serviceName=grpc-service&mode=gun&security=tls&encryption=none&sni=${DOMAIN}#${SERVICE_NAME}-gRPC"
            ;;
        "trojan")
            # Note: Trojan here uses gRPC transport as defined in config.json. Client should use Trojan-gRPC.
            SHARE_LINK="trojan://${UUID}@${DOMAIN}:443?type=grpc&serviceName=grpc-service&mode=gun&security=tls&sni=${DOMAIN}#${SERVICE_NAME}-Trojan-gRPC"
            FOOTNOTE="*Client Setup:* Address: \`${DOMAIN}\`, Port: 443, Security: TLS. *MUST* use Trojan with gRPC Transport mode and ServiceName: \`grpc-service\`."
            ;;
    esac

    local MESSAGE="*Cloud Run Deploy → Successful ✅*
━━━━━━━━━━━━━━━━━━━━
*Project:* \`${PROJECT_ID}\`
*Protocol:* \`${PROTOCOL}\`
*Service:* \`${SERVICE_NAME}\`
*Region:* \`${REGION}\`
*URL:* \`${SERVICE_URL}\`

\`\`\`
${SHARE_LINK}
\`\`\`
*UUID/Password:* \`${ALL_PASSWORDS}\`
━━━━━━━━━━━━━━━━━━━━
${FOOTNOTE}
"

    local CONSOLE_MESSAGE="Cloud Run Deploy Success ✅
━━━━━━━━━━━━━━━━━━━━
Project: ${PROJECT_ID}
Protocol: ${PROTOCOL}
Service: ${SERVICE_NAME}
Region: ${REGION}
URL: ${SERVICE_URL}

${SHARE_LINK}

UUID/Password: ${ALL_PASSWORDS}

${FOOTNOTE}
━━━━━━━━━━━━━━━━━━━━"

    echo "$CONSOLE_MESSAGE" > deployment-info.txt
    success "Info saved to deployment-info.txt"
    echo
    print_header "📄 Deployment Information"
    echo "$CONSOLE_MESSAGE"
    echo

    [[ "$TELEGRAM_DESTINATION" != "none" ]] && { log "Sending to Telegram..."; send_deployment_notification "$MESSAGE"; }

    success "Deployment completed! URL: $SERVICE_URL"
    log "Tip: Monitor costs in GCP Console. Next time, re-run the script in a clean folder."
}

# Run main
main "$@"
