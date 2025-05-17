# FULL TUTORIAL GENSYN AI

Requirements:
1. VPS (Virtual Private Server)
> `i use contabo server (12gb RAM, 6 vCPU Cores) : https://contabo.com/en/vps/`
2. ngrok
> `register : http://dashboard.ngrok.com/`

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
- http://dashboard.ngrok.com/login
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

### Double Check Ngrok
```bash
ngrok http http:://localhost:3000
```
make sure ngrok use the email you are using

### Get Back Inside the Screen
```bash
screen -r gensyn
```

Run RL Swarm!
```bash
./run_rl_swarm.sh
```

### Now that RL Swarm is Running
- Do you want to connect to the testnet : Y
- Use Math (A)
- Parameter 0.5
- Upload to HuggingFace : N
`Now you should see 3 unique animal words and PeerID, save it to track your progress`

### Important!
- Back up your temp-data - inside rl-swarm/modal-login/temp-data (save it somewhere save, do not lose it!)
- Back up swarm.pem - inside rl-swarm (save it somewhere save, do not lose it!)

# TROUBLESHOOTING

### Daemon failed to start in 15.0 seconds
```bash
nano $(python3 -c "import hivemind.p2p.p2p_daemon as m; print(m.__file__)")
```
find this `startup_timeout: float = 15` and change it into `startup_timeout: float = 120`

### Daemon failed to start: 2025/05/15 xxxxxx failed to connect to bootstrap peers
```bash
nano hivemind_exp/runner/gensyn/testnet_grpo_runner.py
```

Change This:
```bash
def get initial peers (self) →> list[str]:
return self.coordinator.get bootnodes()
```

Into:
```bash
def get_initial_peers(self) -> list[str]:
    # Skip chain lookup if no peers provided
        if not getattr(self, 'force_chain_lookup', True):
                return []

    # Original chain lookup
        peers = self.coordinator.get_bootnodes()
        logger.info(f"Bootnodes from chain: {peers}")

    # Filter out dead peers (optional)
        alive_peers = [p for p in peers if not p.startswith('/ip4/38.101.215.15')]
        return alive_peers if alive_peers else []
```



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

### If Already taken by another peer
```bash
killall -9 python
killall -9 p2pd
```
Use this command to check if peer already killed or not
`ps aux | grep swarm`
`ps aux | grep p2pd`