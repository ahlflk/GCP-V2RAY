#!/bin/bash

# ===============================================
# 🛡️ Error Handling
# ===============================================
set -euo pipefail

# 🎨 Color Codes & Emojis
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
ORANGE='\033[0;38;5;208m'
WHITE='\033[0;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
NC='\033[0m' # No Color

# 🌟 Emoji Definitions
EMOJI_START="🚀"
EMOJI_SUCCESS="✅"
EMOJI_FAIL="❌"
EMOJI_INFO="💡"
EMOJI_WAIT="⏳"
EMOJI_PROMPT="❓"
EMOJI_CONFIG="⚙️"
EMOJI_LINK="🔗"
EMOJI_TITLE="✨"
EMOJI_PROTO="🌐"
EMOJI_LOCATION="🗺️"
EMOJI_CPU="🧠"
EMOJI_MEMORY="💾"
EMOJI_NAME="🏷️"
EMOJI_DOMAIN="🛡️"
EMOJI_TELE="📢"
EMOJI_TIME="🕒"

# 🗂️ Global Variables
REPO_URL="https://github.com/ahlflk/GCP-V2RAY.git"
REPO_DIR="GCP-V2RAY"
DEFAULT_SERVICE_NAME="gcp-ahlflk"
DEFAULT_HOST_DOMAIN="m.googleapis.com"
DEFAULT_GRPC_SERVICE="ahlflk"
DEFAULT_TROJAN_PASS="ahlflk"  # Changed to ahlflk
DEFAULT_UUID="3675119c-14fc-46a4-b5f3-9a2c91a7d802"
GCP_PROJECT_ID=""
CPU_LIMIT=""
MEMORY_LIMIT=""
USER_ID=$DEFAULT_UUID
GRPC_SERVICE_NAME=$DEFAULT_GRPC_SERVICE
VLESS_PATH="ahlflk"  # Changed to ahlflk
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
TELEGRAM_CHOICE="1" # Default: Do Not Send
DEPLOYMENT_INFO_FILE="deployment-info.txt"

# =================== Timezone Setup ===================
export TZ="Asia/Yangon"
START_EPOCH="$(date +%s)"
END_EPOCH="$(( START_EPOCH + 5*3600 ))"
fmt_dt() { date -d @"$1" "+%d.%m.%Y %I:%M %p"; }
START_LOCAL="$(fmt_dt "$START_EPOCH")"
END_LOCAL="$(fmt_dt "$END_EPOCH")"

# -----------------------------------------------
# 🖼️ Helper Functions
# -----------------------------------------------

# Function for Header Title
header() {
    local title="$1"
    local emoji="$2"
    local text="$emoji $title"
    local text_len=${#text}
    local total_width=$(( text_len + 4 )) 

    local border_line=""
    for ((i=1; i<=$total_width; i++)); do
        if [ $((i % 2)) -eq 0 ]; then
            border_line+="×"
        else
            border_line+="="
        fi
    done
    
    echo -e "\n${ORANGE}${BOLD}"
    echo " ${border_line} "
    echo " $text  |" 
    echo " ${border_line} "
    echo -e "${NC}"
}

# Key-Value Display for Time
kv() {
    local key="$1"
    local value="$2"
    echo -e "${BLUE}${key}${NC} ${GREEN}${value}${NC}"
}

# UUID Generator using Bash 
generate_uuid() {
    local N=16
    local uuid_string=""
    local hex_chars="0123456789abcdef"
    
    for i in {1..32}; do
        uuid_string="${uuid_string}${hex_chars:$(( RANDOM % $N )):1}"
    done

    local version="4"
    local variant="${hex_chars:$(( (RANDOM % 4) + 8 )):1}" 

    echo "${uuid_string:0:8}-${uuid_string:8:4}-${version}${uuid_string:13:3}-${variant}${uuid_string:17:3}-${uuid_string:20:12}"
}

# General Helpers
log() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> deploy.log; }
error() { 
    echo -e "${RED}ERROR:${NC} $1" 1>&2; log "ERROR: $1"; 
    read -rp "$(echo -e "${EMOJI_FAIL} ${RED}Press [Enter] to exit...${NC}")"
    exit 1; 
}
warn() { echo -e "${YELLOW}WARNING:${NC} $1"; log "WARNING: $1"; }
info() { echo -e "${BLUE}INFO:${NC} $1"; log "INFO: $1"; }
selected() { echo -e "${EMOJI_SUCCESS} ${GREEN}${BOLD}Selected:${NC} ${CYAN}${UNDERLINE}$1${NC}"; log "Selected: $1"; }

# Progress Bar
progress_bar() {
    local duration=$1; local bar_length=20; local elapsed=0;
    echo -n "${EMOJI_WAIT} Processing..."
    while [ "$elapsed" -lt "$duration" ]; do
        local progress=$(( ($elapsed * $bar_length) / $duration )); 
        local filled=$(printf '%.0s#' $(seq 1 $progress)); 
        local empty=$(printf '%.0s-' $(seq 1 $(( $bar_length - $progress ))));
        printf "\r${EMOJI_WAIT} [${GREEN}${filled}${CYAN}${empty}${NC}] %3d%%" $(( ($elapsed * 100) / $duration ))
        sleep 1; elapsed=$(( $elapsed + 1 ))
    done
    printf "\r${EMOJI_WAIT} [${GREEN}$(printf '%.0s#' $(seq 1 $bar_length))${NC}] 100%% Complete! ${EMOJI_SUCCESS}\n"
}

start_and_wait() {
    local command_to_run="$1"
    
    # Disable job control to suppress [1] + done messages
    set +m
    eval "$command_to_run" >/dev/null 2>&1 &
    local command_pid=$!
    set -m
    
    progress_bar 60
    
    if ! wait $command_pid; then
        error "Command failed. Please check the GCP console or network connectivity."
    fi
    
    return 0
}

validate_uuid() { local uuid_pattern="^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"; if [[ ! "$1" =~ $uuid_pattern ]]; then error "Invalid UUID format: $1"; fi; return 0; }
validate_bot_token() { local token_pattern="^[0-9]{9,10}:[a-zA-Z0-9_-]{35}$"; if [[ ! "$1" =~ $token_pattern ]]; then error "Invalid Telegram Bot Token format"; fi; return 0; }
validate_channel_id() { if [[ ! "$1" =~ ^-?[0-9]+$ ]]; then error "Invalid Channel/Group ID format"; fi; return 0; }

# Function to Save Deployment Info to File
save_deployment_info() {
    local service_url="$1"
    local xray_link="$2"
    echo -e "===== GCP XRAY Deployment Info =====" > "$DEPLOYMENT_INFO_FILE"
    echo -e "Deployment Start Time: $START_LOCAL" >> "$DEPLOYMENT_INFO_FILE"
    echo -e "Deployment End Time: $END_LOCAL" >> "$DEPLOYMENT_INFO_FILE"
    echo -e "Protocol: $PROTOCOL" >> "$DEPLOYMENT_INFO_FILE"
    echo -e "Region: $REGION" >> "$DEPLOYMENT_INFO_FILE"
    echo -e "Service Name: $SERVICE_NAME" >> "$DEPLOYMENT_INFO_FILE"
    echo -e "Host/SNI: $HOST_DOMAIN" >> "$DEPLOYMENT_INFO_FILE"
    echo -e "UUID/Password: $USER_ID" >> "$DEPLOYMENT_INFO_FILE"
    if [[ "$PROTOCOL_LOWER" == "vlessgrpc" ]]; then
        echo -e "gRPC Service Name: $GRPC_SERVICE_NAME" >> "$DEPLOYMENT_INFO_FILE"
    fi
    echo -e "Cloud Run URL: $service_url" >> "$DEPLOYMENT_INFO_FILE"
    echo -e "XRAY Configuration Link: $xray_link" >> "$DEPLOYMENT_INFO_FILE"
    echo -e "===================================" >> "$DEPLOYMENT_INFO_FILE"
    info "Deployment info saved to ${CYAN}$DEPLOYMENT_INFO_FILE${NC}"
}

send_telegram_notification() {
    local message="$1"
    local telegram_url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"

    if [[ -n "$TELEGRAM_CHAT_ID" ]]; then
        curl -s -X POST "$telegram_url" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$message" \
            -d parse_mode="Markdown" >/dev/null 2>&1 || warn "Failed to send message to Chat ID: $TELEGRAM_CHAT_ID"
    fi

    if [[ "$TELEGRAM_CHOICE" == "4" && -z "$TELEGRAM_CHAT_ID" ]] || [[ "$TELEGRAM_CHOICE" == "5" && -z "$TELEGRAM_CHAT_ID" ]]; then
        local bot_owner_id=$(echo "$TELEGRAM_BOT_TOKEN" | cut -d ':' -f 1)
        curl -s -X POST "$telegram_url" \
            -d chat_id="$bot_owner_id" \
            -d text="$message" \
            -d parse_mode="Markdown" >/dev/null 2>&1 || warn "Failed to send message to Bot Private Chat"
    fi
}

# ===============================================
# ⚙️ Configuration Options
# ===============================================

header "V2RAY/TROJAN PROTOCOL SELECTION" "$EMOJI_PROTO"
VLESS_PROTOCOL="Vless (WS)"
VLESS_GRPC_PROTOCOL="Vless gRPC"
TROJAN_PROTOCOL="Trojan"

VLESS_DEFAULT="1"
echo -e "  1. ${CYAN}${VLESS_PROTOCOL}${NC} ${GREEN}(Default)${NC}"
echo -e "  2. ${CYAN}${VLESS_GRPC_PROTOCOL}${NC}"
echo -e "  3. ${CYAN}${TROJAN_PROTOCOL}${NC}"
echo
read -rp "$(echo -e "${EMOJI_PROMPT} Enter your choice (1/2/3) [${VLESS_DEFAULT}]: ${NC}")" PROTOCOL_CHOICE
PROTOCOL_CHOICE=${PROTOCOL_CHOICE:-$VLESS_DEFAULT}

case "$PROTOCOL_CHOICE" in
    1) PROTOCOL=$VLESS_PROTOCOL; PROTOCOL_LOWER="vless"; VLESS_PATH="ahlflk";;  # Changed to ahlflk
    2) PROTOCOL=$VLESS_GRPC_PROTOCOL; PROTOCOL_LOWER="vlessgrpc"; VLESS_PATH="ahlflk";;  # Changed to ahlflk
    3) PROTOCOL=$TROJAN_PROTOCOL; PROTOCOL_LOWER="trojan"; VLESS_PATH="ahlflk";;  # Changed to ahlflk
    *) error "Invalid choice. Exiting.";;
esac
selected "$PROTOCOL"

header "CLOUD RUN REGION SELECTION" "$EMOJI_LOCATION"
REGIONS=(
    " 🇺🇸 us-central1 (Council Bluffs, Iowa, North America) ${GREEN}(Default)${NC}" 
    " 🇺🇸 us-east1 (Moncks Corner, South Carolina, North America)" 
    " 🇺🇸 us-south1 (Dallas, Texas, North America)" 
    " 🇺🇸 us-west1 (The Dalles, Oregon, North America)" 
    " 🇺🇸 us-west2 (Los Angeles, California, North America)" 
    " 🇨🇦 northamerica-northeast2 (Toronto, Ontario, North America)" 
    " 🇸🇬 asia-southeast1 (Jurong West, Singapore)" 
    " 🇯🇵 asia-northeast1 (Tokyo, Japan)" 
    " 🇹🇼 asia-east1 (Changhua County, Taiwan)" 
    "🇭🇰 asia-east2 (Hong Kong)" 
    "🇮🇳 asia-south1 (Mumbai, India)" 
    "🇮🇩 asia-southeast2 (Jakarta, Indonesia)" 
)
DEFAULT_REGION_INDEX=1 
for i in "${!REGIONS[@]}"; do
    echo -e "  $((i+1)). ${REGIONS[$i]}"
done
echo
read -rp "$(echo -e "${EMOJI_PROMPT} Enter your choice (1-${#REGIONS[@]}) or Enter [${DEFAULT_REGION_INDEX}]: ${NC}")" REGION_CHOICE
REGION_CHOICE=${REGION_CHOICE:-$DEFAULT_REGION_INDEX}
if [[ "$REGION_CHOICE" -ge 1 && "$REGION_CHOICE" -le ${#REGIONS[@]} ]]; then
    REGION=$(echo "${REGIONS[$((REGION_CHOICE-1))]}" | awk '{print $2}') 
else
    error "Invalid choice. Exiting."
fi
selected "$REGION"

header "CPU LIMIT SELECTION" "$EMOJI_CPU"
CPU_OPTIONS=(
    "1  CPU Core (Low Cost)"
    "2  CPU Cores (Balance) ${GREEN}(Default)${NC}" 
    "4  CPU Cores (Performance)"
    "8  CPU Cores (High Perf)"
    "16 CPU Cores (Max Perf)"
)
CPUS=(1 2 4 8 16)
DEFAULT_CPU_INDEX=2
for i in "${!CPU_OPTIONS[@]}"; do
    echo -e "  $((i+1)). ${CPU_OPTIONS[$i]}"
done
echo
read -rp "$(echo -e "${EMOJI_PROMPT} Enter your choice (1-${#CPUS[@]}) or Enter [${DEFAULT_CPU_INDEX}]: ${NC}")" CPU_CHOICE
CPU_CHOICE=${CPU_CHOICE:-$DEFAULT_CPU_INDEX}
if [[ "$CPU_CHOICE" -ge 1 && "$CPU_CHOICE" -le ${#CPUS[@]} ]]; then
    CPU_LIMIT="${CPUS[$((CPU_CHOICE-1))]}"
else
    error "Invalid choice. Exiting."
fi
selected "${CPU_LIMIT} CPU Cores"

header "MEMORY LIMIT SELECTION" "$EMOJI_MEMORY"
MEMORY_OPTIONS=(
    "1. 512Mi (Minimum/Low Cost)" 
    "2. 1Gi (Low Cost)"
    "3. 2Gi (Balance) ${GREEN}(Default)${NC}" 
    "4. 4Gi (Performance)"
    "5. 8Gi (High Perf)"
    "6. 16Gi (Large Scale)"
    "7. 32Gi (Max)"
)
MEMORIES=("512Mi" "1Gi" "2Gi" "4Gi" "8Gi" "16Gi" "32Gi")
DEFAULT_MEMORY_INDEX=3
for opt in "${MEMORY_OPTIONS[@]}"; do
    echo -e "  ${opt}"
done
echo
read -rp "$(echo -e "${EMOJI_PROMPT} Enter your choice (1-${#MEMORIES[@]}) or Enter [${DEFAULT_MEMORY_INDEX}]: ${NC}")" MEMORY_CHOICE
MEMORY_CHOICE=${MEMORY_CHOICE:-$DEFAULT_MEMORY_INDEX}
if [[ "$MEMORY_CHOICE" -ge 1 && "$MEMORY_CHOICE" -le ${#MEMORIES[@]} ]]; then
    MEMORY_LIMIT="${MEMORIES[$((MEMORY_CHOICE-1))]}"
else
    error "Invalid choice. Exiting."
fi
selected "$MEMORY_LIMIT"

header "CLOUD RUN SERVICE NAME" "$EMOJI_NAME"
echo -e "${EMOJI_INFO} Default Service Name: ${CYAN}${DEFAULT_SERVICE_NAME}${NC} ${GREEN}(Default)${NC}"
echo
read -rp "$(echo -e "${EMOJI_PROMPT} Enter Custom Service Name or Enter [${DEFAULT_SERVICE_NAME}]: ${NC}")" CUSTOM_SERVICE_NAME
SERVICE_NAME=${CUSTOM_SERVICE_NAME:-$DEFAULT_SERVICE_NAME}
SERVICE_NAME=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-')
if [[ -z "$SERVICE_NAME" ]]; then
    SERVICE_NAME=$DEFAULT_SERVICE_NAME
    info "Service Name was empty or invalid. Using default: ${CYAN}$SERVICE_NAME${NC}"
fi
selected "$SERVICE_NAME"

header "HOST DOMAIN (SNI)" "$EMOJI_DOMAIN"
echo -e "${EMOJI_INFO} Default Host Domain: ${CYAN}${DEFAULT_HOST_DOMAIN}${NC} ${GREEN}(Default)${NC}"
echo
read -rp "$(echo -e "${EMOJI_PROMPT} Enter Custom Host Domain or Enter [${DEFAULT_HOST_DOMAIN}]: ${NC}")" CUSTOM_HOST_DOMAIN
HOST_DOMAIN=${CUSTOM_HOST_DOMAIN:-$DEFAULT_HOST_DOMAIN}
selected "$HOST_DOMAIN"

if [[ "$PROTOCOL_LOWER" != "trojan" ]]; then
    header "VLESS USER ID (UUID)" "$EMOJI_CONFIG"
    echo -e "  1. ${CYAN}${DEFAULT_UUID}${NC} ${GREEN}(Default)${NC}"
    echo -e "  2. ${CYAN}Random UUID Generate (Internal Bash)${NC}"
    echo -e "  3. ${CYAN}Custom UUID${NC}"
    echo
    DEFAULT_UUID_CHOICE="1"
    read -rp "$(echo -e "${EMOJI_PROMPT} Enter your choice (1/2/3) or Enter [1]: ${NC}")" UUID_CHOICE
    UUID_CHOICE=${UUID_CHOICE:-$DEFAULT_UUID_CHOICE}
    
    case "$UUID_CHOICE" in
        1) USER_ID=$DEFAULT_UUID ;;
        2) USER_ID=$(generate_uuid); info "Generated UUID: ${CYAN}$USER_ID${NC}";;
        3) read -rp "$(echo -e "${EMOJI_PROMPT} Enter Custom UUID: ${NC}")" CUSTOM_UUID
           validate_uuid "$CUSTOM_UUID"
           USER_ID=$CUSTOM_UUID ;;
        *) warn "Invalid choice. Using Default UUID."; USER_ID=$DEFAULT_UUID ;;
    esac
    selected "$USER_ID"
    
    if [[ "$PROTOCOL_LOWER" == "vlessgrpc" ]]; then
        header "gRPC SERVICE NAME" "$EMOJI_CONFIG"
        echo -e "${EMOJI_INFO} Default gRPC Service Name: ${CYAN}${DEFAULT_GRPC_SERVICE}${NC} ${GREEN}(Default)${NC}"
        echo
        read -rp "$(echo -e "${EMOJI_PROMPT} Enter Custom gRPC Service Name or Enter [${DEFAULT_GRPC_SERVICE}]: ${NC}")" CUSTOM_GRPC_SERVICE
        GRPC_SERVICE_NAME=${CUSTOM_GRPC_SERVICE:-$DEFAULT_GRPC_SERVICE}
        VLESS_PATH="ahlflk"  # Changed to ahlflk
        selected "$GRPC_SERVICE_NAME"
    fi
    
else
    header "TROJAN PASSWORD" "$EMOJI_CONFIG"
    echo -e "${EMOJI_INFO} Default Password: ${CYAN}${DEFAULT_TROJAN_PASS}${NC} ${GREEN}(Default)${NC}"
    echo
    read -rp "$(echo -e "${EMOJI_PROMPT} Enter Custom Password or Enter [${DEFAULT_TROJAN_PASS}]: ${NC}")" CUSTOM_TROJAN_PASS
    USER_ID=${CUSTOM_TROJAN_PASS:-$DEFAULT_TROJAN_PASS}
    selected "$USER_ID"
fi

header "TELEGRAM SHARING OPTIONS" "$EMOJI_TELE"
TELEGRAM_OPTIONS=(
    "1. Do Not Send Telegram ${GREEN}(Default)${NC}"
    "2. Send to Channel Only"
    "3. Send to Group Only"
    "4. Send to Bot (Private Chat)"
    "5. Send to Bot & Channel/Group (Recommended)"
)
DEFAULT_TELEGRAM="1"
for opt in "${TELEGRAM_OPTIONS[@]}"; do
    echo -e "  ${CYAN}${opt}${NC}"
done
echo
read -rp "$(echo -e "${EMOJI_PROMPT} Enter your choice (1-5) or Enter [1]: ${NC}")" TELEGRAM_CHOICE
TELEGRAM_CHOICE=${TELEGRAM_CHOICE:-$DEFAULT_TELEGRAM}
TELEGRAM_MODE="${TELEGRAM_OPTIONS[$((TELEGRAM_CHOICE-1))]}"

if [[ "$TELEGRAM_CHOICE" -ge "2" && "$TELEGRAM_CHOICE" -le "5" ]]; then
    echo
    read -rp "$(echo -e "${EMOJI_PROMPT} Enter Telegram Bot Token (Required): ${NC}")" CUSTOM_BOT_TOKEN
    validate_bot_token "$CUSTOM_BOT_TOKEN"
    TELEGRAM_BOT_TOKEN="$CUSTOM_BOT_TOKEN"

    if [[ "$TELEGRAM_CHOICE" -eq "2" || "$TELEGRAM_CHOICE" -eq "3" || "$TELEGRAM_CHOICE" -eq "5" ]]; then
        echo
        read -rp "$(echo -e "${EMOJI_PROMPT} Enter Telegram Chat ID (Channel/Group ID: -12345...): ${NC}")" CUSTOM_CHAT_ID
        validate_channel_id "$CUSTOM_CHAT_ID" 
        TELEGRAM_CHAT_ID="$CUSTOM_CHAT_ID"
    fi
fi
selected "$(echo "$TELEGRAM_MODE" | sed 's/ *\[Default\]//g')"

# ===============================================
# 📄 Display Configuration Summary & Confirmation
# ===============================================
header "DEPLOYMENT CONFIGURATION SUMMARY" "$EMOJI_CONFIG"

if command -v gcloud >/dev/null 2>&1; then
    GCP_PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
    if [ -z "$GCP_PROJECT_ID" ]; then
        GCP_PROJECT_ID="<GCP Project ID Not Configured>"
        warn "GCP Project ID not set in gcloud config. Please configure it or the pre-check will fail."
    fi
else
    GCP_PROJECT_ID="<GCP CLI Not Found - Check Pre-Requisites>"
    echo -e "${RED}${BOLD}NOTE:${NC} The gcloud CLI is not detected. Pre-requisite check will run next."
fi

echo -e "${EMOJI_CONFIG} ${BLUE}${BOLD}Project ID:${NC}      ${GREEN}${GCP_PROJECT_ID}${NC}" 
echo -e "${EMOJI_CONFIG} ${BLUE}Protocol:${NC}        ${GREEN}$PROTOCOL${NC}"
echo -e "${EMOJI_CONFIG} ${BLUE}Service Name:${NC}    ${GREEN}$SERVICE_NAME${NC}"
echo -e "${EMOJI_CONFIG} ${BLUE}Region:${NC}          ${GREEN}$REGION${NC}"
echo -e "${EMOJI_CONFIG} ${BLUE}CPU Limit:${NC}       ${GREEN}${CPU_LIMIT} CPU Cores${NC}"
echo -e "${EMOJI_CONFIG} ${BLUE}Memory Limit:${NC}    ${GREEN}${MEMORY_LIMIT}${NC}"
echo -e "${EMOJI_CONFIG} ${BLUE}Host Domain/SNI:${NC} ${GREEN}$HOST_DOMAIN${NC}"
echo -e "${EMOJI_CONFIG} ${BLUE}UUID/Password:${NC}   ${GREEN}$USER_ID${NC}"
if [ "$TELEGRAM_CHOICE" -ne "1" ]; then
    echo -e "${EMOJI_CONFIG} ${BLUE}Telegram Mode:${NC}     ${GREEN}$TELEGRAM_MODE${NC}"
    echo -e "${EMOJI_CONFIG} ${BLUE}Telegram Chat ID:${NC}  ${GREEN}${TELEGRAM_CHAT_ID:-N/A}${NC}"
fi

header "DEPLOYMENT TIME" "$EMOJI_TIME"
kv "Start:" "${START_LOCAL}"
kv "End:"   "${END_LOCAL}"

echo -e "\n${YELLOW}${EMOJI_START} Configuration is complete.${NC}"
read -rp "$(echo -e "${EMOJI_PROMPT} Continue with deployment? (Y/n) [Y]: ${NC}")" CONFIRM_DEPLOY
CONFIRM_DEPLOY=${CONFIRM_DEPLOY:-Y}

if [[ ! "$CONFIRM_DEPLOY" =~ ^[Yy]$ ]]; then
    info "Deployment cancelled by user. Exiting."
    exit 0
fi

# ===============================================
# 🛠️ Pre-Requisite Check
# ===============================================
header "PRE-REQUISITE CHECK" "$EMOJI_CPU"
info "Checking for all required CLI tools..."

progress_bar 5

command -v gcloud >/dev/null 2>&1 || error "gcloud CLI not found. Please install and authenticate with 'gcloud auth login' and 'gcloud config set project <ID>'."
command -v docker >/dev/null 2>&1 || error "docker not found. Please install it."
command -v git >/dev/null 2>&1 || error "git not found. Please install it."

GCP_PROJECT_ID=$(gcloud config get-value project)
if [ -z "$GCP_PROJECT_ID" ]; then
    error "GCP Project ID not set in gcloud config. Please run 'gcloud config set project <YOUR_PROJECT_ID>'."
fi
info "GCP Project ID: ${GREEN}$GCP_PROJECT_ID${NC}"

info "All required CLI tools found. Starting GCP setup."

# ===============================================
# ☁️ GCP Project ID & API Setup
# ===============================================
header "GCP SETUP & API ENABLEMENT" "$EMOJI_START"

gcloud config set project "$GCP_PROJECT_ID" --quiet >/dev/null 2>&1
info "Enabling necessary APIs (Cloud Run, Container Registry)..."

API_CMD="gcloud services enable run.googleapis.com containerregistry.googleapis.com --project=\"$GCP_PROJECT_ID\""

progress_bar 10 
if ! API_OUTPUT=$(eval "$API_CMD" 2>&1); then
    echo -e "\n${RED}--- GCP API ENABLEMENT ERROR LOG ---${NC}"
    echo "$API_OUTPUT" 1>&2
    echo -e "${RED}------------------------------------${NC}\n"
    error "GCP APIs could not be enabled. Please check permissions for user ${GCP_PROJECT_ID}."
fi

info "APIs enabled successfully."

# ===============================================
# 🏗️ Clone & File Generation
# ===============================================
header "GIT CLONE & CONFIG FILE PREP" "$EMOJI_CONFIG"

info "Git Clone URL: ${CYAN}${REPO_URL}${NC}"
if [ -d "$REPO_DIR" ]; then
    info "Removing existing repo $REPO_DIR and recloning."
    rm -rf "$REPO_DIR"
fi
info "Cloning $REPO_URL..."
progress_bar 5
if ! git clone "$REPO_URL" >/dev/null 2>&1; then
    error "Git Clone failed. Check if the repository URL is correct or if Git is configured."
fi
info "Git Clone successful."
cd "$REPO_DIR"

info "Configuring config.json..."

if [ ! -f "config.json" ]; then
    error "config.json not found in the repository. Deployment aborted."
fi

# Configure config.json based on protocol
case "$PROTOCOL_LOWER" in
    "vless")
        sed -i "s/PLACEHOLDER_UUID/$USER_ID/g" config.json
        sed -i "s|/vless|$VLESS_PATH|g" config.json
        info "VLESS-WS config prepared with UUID and Path"
        ;;
    "vlessgrpc")
        sed -i "s/PLACEHOLDER_UUID/$USER_ID/g" config.json
        sed -i "s|\"network\": \"ws\"|\"network\": \"grpc\"|g" config.json
        sed -i "s|\"wsSettings\": { \"path\": \"/vless\" }|\"grpcSettings\": { \"serviceName\": \"$GRPC_SERVICE_NAME\" }|g" config.json
        info "VLESS-gRPC config prepared with UUID and ServiceName"
        ;;
    "trojan")
        sed -i 's|"protocol": "vless"|"protocol": "trojan"|g' config.json
        sed -i "s|\"clients\": \[ { \"id\": \"PLACEHOLDER_UUID\" } ]|\"users\": \[ { \"password\": \"$USER_ID\" } ]|g" config.json
        sed -i "s|\"path\": \"/vless\"|\"path\": \"$VLESS_PATH\"|g" config.json
        info "Trojan-WS config prepared with Password and Path"
        ;;
    *)
        error "Unknown protocol: $PROTOCOL_LOWER. Cannot prepare config."
        ;;
esac

info "config.json configured successfully."

# ===============================================
# 🛠️ DOCKER BUILD & CONTAINER REGISTRY PUSH
# ===============================================
header "DOCKER IMAGE BUILD & PUSH" "$EMOJI_START"

IMAGE_TAG="gcr.io/$GCP_PROJECT_ID/gcp-v2ray-image:latest"

info "Building Docker Image: ${CYAN}$IMAGE_TAG${NC}..."
progress_bar 10
if ! DOCKER_BUILD_OUTPUT=$(docker build -t "$IMAGE_TAG" . 2>&1); then
    echo -e "\n${RED}--- DOCKER BUILD ERROR LOG ---${NC}"
    echo "$DOCKER_BUILD_OUTPUT" 1>&2
    echo -e "${RED}------------------------------${NC}\n"
    error "Docker build failed. See the log above for details (Check Dockerfile and internet connectivity)."
fi
info "Docker image built successfully."

info "Pushing Docker Image to Container Registry..."
progress_bar 30
if ! docker push "$IMAGE_TAG" >/dev/null 2>&1; then
    error "Docker push failed. Check your network or permissions."
fi
info "Image pushed successfully."

# ===============================================
# ☁️ CLOUD RUN SERVICE DEPLOY
# ===============================================
header "CLOUD RUN SERVICE DEPLOYMENT" "$EMOJI_WAIT"

info "Deploying Cloud Run Service: ${CYAN}$SERVICE_NAME${NC} in ${CYAN}$REGION${NC}..."

DEPLOY_COMMAND="gcloud run deploy \"$SERVICE_NAME\" \
    --image=\"$IMAGE_TAG\" \
    --region=\"$REGION\" \
    --cpu=\"$CPU_LIMIT\" \
    --memory=\"$MEMORY_LIMIT\" \
    --allow-unauthenticated \
    --port=8080 \
    --project=\"$GCP_PROJECT_ID\" \
    --quiet"

if [[ $CPU_LIMIT == "16" ]]; then
    DEPLOY_COMMAND="$DEPLOY_COMMAND --machine-type e2-standard-16"
fi

if ! start_and_wait "$DEPLOY_COMMAND"; then
    error "Cloud Run deployment failed. Check the GCP console for deployment logs."
fi

info "Deployment successful! Service is now fully ready. ${EMOJI_SUCCESS}"

# ===============================================
# 🎉 FINAL CONFIGURATION LINK GENERATION & SHARING
# ===============================================
header "DEPLOYMENT SUCCESS & CONFIG LINK" "$EMOJI_SUCCESS"
echo -e "\n${GREEN}${BOLD}======================================================${NC}"
echo -e "${EMOJI_SUCCESS} ${GREEN}${BOLD}SERVICE DEPLOYED SUCCESSFULLY! SERVICE IS ACTIVE.${NC} ${EMOJI_SUCCESS}"
echo -e "${GREEN}${BOLD}======================================================${NC}\n"

SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" \
    --format='value(status.url)' \
    --project="$GCP_PROJECT_ID" 2>/dev/null)

if [ -z "$SERVICE_URL" ]; then
    error "Failed to retrieve the Service URL after deployment. Service might be in a failed state."
fi

HOST_NAME=$(echo "$SERVICE_URL" | sed -E 's|https://||; s|/||')

URL_PATH_ENCODED=$(echo "$VLESS_PATH" | sed 's/\//%2F/g')
XRAY_LINK_LABEL="GCP-${PROTOCOL_LOWER^^}-${SERVICE_NAME}"
XRAY_LINK=""

if [[ "$PROTOCOL_LOWER" == "vless" ]]; then
    XRAY_LINK="vless://${USER_ID}@${HOST_DOMAIN}:443?encryption=none&security=tls&host=${HOST_NAME}&path=${URL_PATH_ENCODED}&type=ws&sni=${HOST_NAME}#${XRAY_LINK_LABEL}"
elif [[ "$PROTOCOL_LOWER" == "vlessgrpc" ]]; then
    XRAY_LINK="vless://${USER_ID}@${HOST_DOMAIN}:443?encryption=none&security=tls&type=grpc&serviceName=${GRPC_SERVICE_NAME}&sni=${HOST_NAME}#${XRAY_LINK_LABEL}"
elif [[ "$PROTOCOL_LOWER" == "trojan" ]]; then
    XRAY_LINK="trojan://${USER_ID}@${HOST_DOMAIN}:443?security=tls&sni=${HOST_NAME}#${XRAY_LINK_LABEL}"
fi

echo -e "${EMOJI_LINK} ${BLUE}Cloud Run URL:${NC}           ${CYAN}${SERVICE_URL}${NC}"
echo -e "${EMOJI_LINK} ${BLUE}XRAY Configuration Link:${NC}"
echo -e "${GREEN}${BOLD}${XRAY_LINK}${NC}"

# Save Deployment Info to File
save_deployment_info "$SERVICE_URL" "$XRAY_LINK"

if [ "$TELEGRAM_CHOICE" -ne "1" ]; then
    info "Preparing Telegram notification..."
    MESSAGE_BODY=$(cat <<EOF
*GCP XRAY Deployment Success!* ${EMOJI_SUCCESS}

*Deployment Start Time:* ${START_LOCAL}
*Deployment End Time:* ${END_LOCAL}
*Protocol:* ${PROTOCOL}
*Region:* ${REGION}
*Service Name:* \`${SERVICE_NAME}\`
*Host/SNI:* \`${HOST_DOMAIN}\`

*XRAY Configuration Link:*
\`\`\`
${XRAY_LINK}
\`\`\`

*Note:* Tap on the link block to copy the full configuration link.
EOF
)
    send_telegram_notification "$MESSAGE_BODY"
fi

echo -e "\n${EMOJI_TITLE} ${GREEN}${BOLD}Deployment Complete! Your Service is now running.${NC} ${EMOJI_TITLE}"
cd ..
rm -rf "$REPO_DIR"

trap - EXIT
read -rp "$(echo -e "${EMOJI_PROMPT} ${CYAN}Deployment Finished. Press [Enter] to close this window...${NC}")"
exit 0