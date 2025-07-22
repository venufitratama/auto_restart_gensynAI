#!/bin/bash

set -euo pipefail

# General arguments
ROOT=$PWD

# GenRL Swarm version to use
GENRL_TAG="v0.1.1"

export IDENTITY_PATH
export GENSYN_RESET_CONFIG
export CONNECT_TO_TESTNET=true
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120  # 2 minutes
export SWARM_CONTRACT="0xFaD7C5e93f28257429569B854151A1B8DCD404c2"
export HUGGINGFACE_ACCESS_TOKEN="None"

# Path to an RSA private key. If this path does not exist, a new key pair will be created.
# Remove this file if you want a new PeerID.
DEFAULT_IDENTITY_PATH="$ROOT"/swarm.pem
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}

SOURCE_BACKUP_DIR="/root/backup"

DOCKER=${DOCKER:-""}
GENSYN_RESET_CONFIG=${GENSYN_RESET_CONFIG:-""}

# Bit of a workaround for the non-root docker container.
if [ -n "$DOCKER" ]; then
    volumes=(
        /home/gensyn/rl_swarm/modal-login/temp-data
        /home/gensyn/rl_swarm/keys
        /home/gensyn/rl_swarm/configs
        /home/gensyn/rl_swarm/logs
    )

    for volume in ${volumes[@]}; do
        sudo chown -R 1001:1001 $volume
    done
fi

# Will ignore any visible GPUs if set.
CPU_ONLY=${CPU_ONLY:-""}

# Set if successfully parsed from modal-login/temp-data/userData.json.
ORG_ID=${ORG_ID:-""}

GREEN_TEXT="\033[32m"
BLUE_TEXT="\033[34m"
RED_TEXT="\033[31m"
RESET_TEXT="\033[0m"

echo_green() {
    echo -e "$GREEN_TEXT$1$RESET_TEXT"
}

echo_blue() {
    echo -e "$BLUE_TEXT$1$RESET_TEXT"
}

echo_red() {
    echo -e "$RED_TEXT$1$RESET_TEXT"
}

ROOT_DIR="$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)"

# Function to clean up the server process upon exit
cleanup() {
    echo_green ">> Shutting down trainer..."

    # Remove modal credentials if they exist
    rm -r $ROOT_DIR/modal-login/temp-data/*.json 2> /dev/null || true

    # Kill all processes belonging to this script's process group
    kill -- -$$ || true

    exit 0
}

errnotify() {
    echo_red ">> An error was detected while running rl-swarm. See $ROOT/logs for full logs."
}

trap cleanup EXIT
trap errnotify ERR

echo -e "\033[38;5;224m"
cat << "EOF"
    ██████  ██            ███████ ██     ██  █████  ██████  ███    ███
    ██   ██ ██            ██      ██     ██ ██   ██ ██   ██ ████  ████
    ██████  ██      █████ ███████ ██  █  ██ ███████ ██████  ██ ████ ██
    ██   ██ ██                 ██ ██ ███ ██ ██   ██ ██   ██ ██  ██  ██
    ██   ██ ███████       ███████  ███ ███  ██   ██ ██   ██ ██      ██

    From Gensyn

EOF

# Create logs directory if it doesn't exist
mkdir -p "$ROOT/logs"

if [ "$CONNECT_TO_TESTNET" = true ]; then
    # Run modal_login server.
    echo "Please login to create an Ethereum Server Wallet"
    cd modal-login
    # Check if the yarn command exists; if not, install Yarn.

    # Node.js + NVM setup
    if ! command -v node > /dev/null 2>&1; then
        echo "Node.js not found. Installing NVM and latest Node.js..."
        export NVM_DIR="$HOME/.nvm"
        if [ ! -d "$NVM_DIR" ]; then
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        fi
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        nvm install node
    else
        echo "Node.js is already installed: $(node -v)"
    fi

    if ! command -v yarn > /dev/null 2>&1; then
        # Detect Ubuntu (including WSL Ubuntu) and install Yarn accordingly
        if grep -qi "ubuntu" /etc/os-release 2> /dev/null || uname -r | grep -qi "microsoft"; then
            echo "Detected Ubuntu or WSL Ubuntu. Installing Yarn via apt..."
            curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
            echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
            sudo apt update && sudo apt install -y yarn
        else
            echo "Yarn not found. Installing Yarn globally with npm (no profile edits)…"
            # This lands in $NVM_DIR/versions/node/<ver>/bin which is already on PATH
            npm install -g --silent yarn
        fi
    fi

    ENV_FILE="$ROOT"/modal-login/.env
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS version
        sed -i '' "3s/.*/SMART_CONTRACT_ADDRESS=$SWARM_CONTRACT/" "$ENV_FILE"
    else
        # Linux version
        sed -i "3s/.*/SMART_CONTRACT_ADDRESS=$SWARM_CONTRACT/" "$ENV_FILE"
    fi


    # Docker image already builds it, no need to again.
    if [ -z "$DOCKER" ]; then
        yarn install --immutable
        echo "Building server"
        # yarn build > "$ROOT/logs/yarn.log" 2>&1
    fi
    yarn start >> "$ROOT/logs/yarn.log" 2>&1 & # Run in background and log output

    SERVER_PID=$!  # Store the process ID
    echo "Started server process: $SERVER_PID"
    sleep 5

    # Try to open the URL in the default browser
    if [ -z "$DOCKER" ]; then
        if open http://localhost:3000 2> /dev/null; then
            echo_green ">> Successfully opened http://localhost:3000 in your default browser."
        else
            echo ">> Failed to open http://localhost:3000. Please open it manually."
        fi
    else
        echo_green ">> Please open http://localhost:3000 in your host browser."
    fi

    cd ..

    echo_green ">> Waiting for modal userData.json to be created..."
    DEST_MODAL_DATA_DIR="$ROOT/modal-login/temp-data"
    DEST_ROOT_DIR="$ROOT"
    
    login_status="y"
    
    while [ ! -f "$DEST_MODAL_DATA_DIR/userData.json" ]; do
        sleep 5
        
        case "$login_status" in
            y|Y)
                echo_green ">> Melanjutkan dengan proses login..."
                rm -r "$DEST_MODAL_DATA_DIR"/*.json 2> /dev/null || true
    
                if [ -z "$DOCKER" ]; then
                    if ! install_localtunnel || ! start_localtunnel; then
                        if open http://localhost:3000 2> /dev/null; then
                            echo_green ">> Berhasil membuka http://localhost:3000 di browser default Anda."
                        else
                            echo ">> Gagal membuka http://localhost:3000. Harap buka secara manual."
                        fi
                    fi
                else
                    echo_green ">> Harap buka http://localhost:3000 di browser host Anda."
                fi
    
                echo_green ">> Menunggu modal userData.json dibuat..."
                mkdir -p "$DEST_MODAL_DATA_DIR" || { echo_red "ERROR: Gagal membuat direktori $DEST_MODAL_DATA_DIR"; exit 1; }
    
                while [ ! -f "$DEST_MODAL_DATA_DIR/userData.json" ]; do
                    if [ -f "$SOURCE_BACKUP_DIR/userApiKey.json" ] && [ -f "$SOURCE_BACKUP_DIR/userData.json" ]; then
                        echo ">> Menemukan userApiKey.json dan userData.json di $SOURCE_BACKUP_DIR, menyalin ke $DEST_MODAL_DATA_DIR..."
                        cp -f "$SOURCE_BACKUP_DIR/userApiKey.json" "$DEST_MODAL_DATA_DIR" || { echo_red "ERROR: Gagal menyalin userApiKey.json."; exit 1; }
                        cp -f "$SOURCE_BACKUP_DIR/userData.json" "$DEST_MODAL_DATA_DIR" || { echo_red "ERROR: Gagal menyalin userData.json."; exit 1; }
                        echo ">> File userData.json dan userApiKey.json berhasil disalin."
                    else
                        echo ">> Menunggu file userApiKey.json dan userData.json di $SOURCE_BACKUP_DIR..."
                    fi
    
                    if [ -f "$SOURCE_BACKUP_DIR/swarm.pem" ] && [ ! -f "$DEST_ROOT_DIR/swarm.pem" ]; then
                        echo ">> Menemukan swarm.pem di $SOURCE_BACKUP_DIR, menyalin ke $DEST_ROOT_DIR..."
                        cp -f "$SOURCE_BACKUP_DIR/swarm.pem" "$DEST_ROOT_DIR" || { echo_red "ERROR: Gagal menyalin swarm.pem."; exit 1; }
                        echo ">> File swarm.pem berhasil disalin."
                    fi
    
                    [ -f "$DEST_MODAL_DATA_DIR/userData.json" ] && break
                    sleep 5
                done
                echo "Found userData.json. Proceeding..."
                ;;
            n|N)
                echo_green ">> Melanjutkan tanpa login ulang. Memastikan file credential tersedia..."
                mkdir -p "$DEST_MODAL_DATA_DIR" || { echo_red "ERROR: Gagal membuat direktori $DEST_MODAL_DATA_DIR"; exit 1; }
                if [ -f "$SOURCE_BACKUP_DIR/userApiKey.json" ] && [ -f "$SOURCE_BACKUP_DIR/userData.json" ]; then
                    echo ">> Menemukan file userApiKey.json dan userData.json di $SOURCE_BACKUP_DIR, menyalin ke $DEST_MODAL_DATA_DIR..."
                    cp -f "$SOURCE_BACKUP_DIR/userApiKey.json" "$DEST_MODAL_DATA_DIR" || { echo_red "ERROR: Gagal menyalin userApiKey.json."; exit 1; }
                    cp -f "$SOURCE_BACKUP_DIR/userData.json" "$DEST_MODAL_DATA_DIR" || { echo_red "ERROR: Gagal menyalin userData.json."; exit 1; }
                    echo ">> File userData.json dan userApiKey.json disalin."
                else
                    echo_red "ERROR: File userApiKey.json atau userData.json tidak ditemukan di $SOURCE_BACKUP_DIR. Tidak dapat melanjutkan tanpa login atau file yang ada."
                    exit 1
                fi
    
                if [ -f "$SOURCE_BACKUP_DIR/swarm.pem" ] && [ ! -f "$DEST_ROOT_DIR/swarm.pem" ]; then
                    echo ">> Menemukan swarm.pem di $SOURCE_BACKUP_DIR, menyalin ke $DEST_ROOT_DIR..."
                    cp -f "$SOURCE_BACKUP_DIR/swarm.pem" "$DEST_ROOT_DIR" || { echo_red "ERROR: Gagal menyalin swarm.pem."; exit 1; }
                    echo ">> File swarm.pem disalin."
                fi
    
                if [ ! -f "$DEST_MODAL_DATA_DIR/userData.json" ]; then
                    echo_red "ERROR: userData.json tidak ditemukan setelah proses salin atau verifikasi."
                    exit 1
                fi
                break
                ;;
            *)
                echo_red ">> Perintah tidak valid untuk login_status."
                exit 1
                ;;
        esac
    done
    
    echo "Found userData.json. Proceeding..."

    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)
    echo "Your ORG_ID is set to: $ORG_ID"

    # Wait until the API key is activated by the client
    echo "Waiting for API key to become activated..."
    while true; do
        STATUS=$(curl -s "http://localhost:3000/api/get-api-key-status?orgId=$ORG_ID")
        if [[ "$STATUS" == "activated" ]]; then
            echo "API key is activated! Proceeding..."
            break
        else
            echo "Waiting for API key to be activated..."
            sleep 5
        fi
    done
fi

echo_green ">> Getting requirements..."
pip install --upgrade pip

# echo_green ">> Installing GenRL..."
pip install gensyn-genrl==0.1.4
pip install reasoning-gym>=0.1.20 # for reasoning gym env
pip install trl # for grpo config, will be deprecated soon
pip install hivemind@git+https://github.com/gensyn-ai/hivemind@639c964a8019de63135a2594663b5bec8e5356dd # We need the latest, 1.1.11 is broken


if [ ! -d "$ROOT/configs" ]; then
    mkdir "$ROOT/configs"
fi  
if [ -f "$ROOT/configs/rg-swarm.yaml" ]; then
    # Use cmp -s for a silent comparison. If different, backup and copy.
    if ! cmp -s "$ROOT/rgym_exp/config/rg-swarm.yaml" "$ROOT/configs/rg-swarm.yaml"; then
        if [ -z "$GENSYN_RESET_CONFIG" ]; then
            echo_green ">> Found differences in rg-swarm.yaml. If you would like to reset to the default, set GENSYN_RESET_CONFIG to a non-empty value."
        else
            echo_green ">> Found differences in rg-swarm.yaml. Backing up existing config."
            mv "$ROOT/configs/rg-swarm.yaml" "$ROOT/configs/rg-swarm.yaml.bak"
            cp "$ROOT/rgym_exp/config/rg-swarm.yaml" "$ROOT/configs/rg-swarm.yaml"
        fi
    fi
else
    # If the config doesn't exist, just copy it.
    cp "$ROOT/rgym_exp/config/rg-swarm.yaml" "$ROOT/configs/rg-swarm.yaml"
fi

if [ -n "$DOCKER" ]; then
    # Make it easier to edit the configs on Linux systems.
    sudo chmod -R 0777 /home/gensyn/rl_swarm/configs
fi

echo_green ">> Done!"

HUGGINGFACE_ACCESS_TOKEN="None"
MODEL_NAME="Gensyn/Qwen2.5-0.5B-Instruct"
export MODEL_NAME
export HUGGINGFACE_ACCESS_TOKEN="None"

echo_green ">> Hugging Face push disabled. No token will be used."
echo_green ">> Using model: $MODEL_NAME"

echo_green ">> Good luck in the swarm!"
echo_blue ">> And remember to star the repo on GitHub! --> https://github.com/gensyn-ai/rl-swarm"

echo_green ">> Starting swarm trainer..."

# Comment out `yarn build` in this file itself (only once, not on every restart)
sed -i.bak 's/^\([[:space:]]*\)yarn build/\1# yarn build/' "$ROOT/run_rl_swarm.sh"

while true; do
    if ! python -m rgym_exp.runner.swarm_launcher \
        --config-path "$ROOT/rgym_exp/config" \
        --config-name "rg-swarm.yaml"; then
        echo_red ">> Swarm trainer exited with error. Restarting in 5 seconds... (Press Ctrl+C to stop)"
    else
        echo_green ">> Swarm trainer exited normally. Restarting in 5 seconds... (Press Ctrl+C to stop)"
    fi

    sleep 5
done

wait  # Keep script running until Ctrl+C
