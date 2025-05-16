# FULL TUTORIAL GENSYN AI

Requirements:
1. VPS (Virtual Private Server)
i use contabo server (12gb RAM, 6 vCPU Cores)
2. ngrok
register : dashboard.ngrok.com/login

# INSTALLATION

### Install Dependencies
```bash
apt install npm
```

```bash
apt update && apt install -y sudo
```

```bash
sudo apt update && sudo apt install -y python3 python3-venv python3-pip curl wget screen git lsof nano unzip iproute2
```

```bash
curl -sSL https://raw.githubusercontent.com/zunxbt/installation/main/node.sh | bash
```

### Download Data to Train
```bash
git clone https://github.com/zunxbt/rl-swarm.git
```

### Make Screen & Go To Directory
```bash
screen -S gensyn
```

```bash
cd rl-swarm
```

### Make Virtual Environtment (venv) Inside the Folder
```bash
python3 -m venv .venv
```

### Activate Venv
```bash
source .venv/bin/activate
```
- now, exit from the screen by using CTRL + A + D
- after that you need to download & replace this file `grpo-qwen-2.5-0.5b-deepseek-r1.yaml` into `cd rl-swarm/hivemind_exp/configs/mac/`

### Register Ngrok
- dashboard.ngrok.com/login
- Open this : https://dashboard.ngrok.com/get-started/setup/linux
- Follow the first two step (until here `ngrok config add-authtoken 2vFxxxxxxxxxx`)
- Change third config into : 
```bash
ngrok http http://localhost:3000
```

### Memory Swap
Create a 4GB swap file (adjust size if needed)
```bash
sudo fallocate -l 4G /swapfile
```

Set correct permissions
```bash
sudo chmod 600 /swapfile
```

Format as Swap
```bash
sudo mkswap /swapfile
```

Enable swap
```bash
sudo swapon /swapfile
```

Make it permanent
```bash
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Get Back Inside the Screen
Run RL Swarm!
```bash
./run_rl_swarm.sh
```

### Now that RL Swarm is Running
- Do you want to connect to the testnet : Y
- Use Math (A)
- Parameter 0.5
- Upload to HuggingFace : N


# TROUBLESHOOTING

### Daemon failed to start in 15.0 seconds
```bash
nano $(python3 -c "import hivemind.p2p.p2p_daemon as m; print(m.__file__)")
```
find this `startup_timeout: float = 15` and change it into `startup_timeout: float = 120`

### Waiting for modal userData.json to be created too long (like hours) or Can't login to the website
```bash
nano modal-login/app/page.tsx
```
paste this right above `return (<main className="...">`
```bash
useEffect(() => {
  if (!user && !signerStatus.isInitializing) {
    openAuthModal();
  }
}, [user, signerStatus.isInitializing]);
```

### Hugging Face Problem Like This
`python -m hivemind_exp.gsm8k.train_single_gpu --hf_token "$HUGGINGFACE_ACCESS_TOKEN" --identity_path "$IDENTITY_PATH`
```bash
export HF_HUB_ENABLE_HF_TRANSFER=0
```
