#GENSYN AI

# INSTALLATION

### Install Dependencies (Guide For GCP/ Azure non Root User)
1. Dependencies
```bash
sudo apt update && sudo apt install -y sudo
```

```bash
sudo apt update && sudo apt install -y python3 python3-venv python3-pip curl wget screen git lsof nano unzip iproute2 build-essential gcc g++
```

2. Clone Repository
```bash
git clone https://github.com/venufitratama/auto_restart_gensynAI.git
```

```bash
cd auto_restart_gensynAI/
```

Move the file, adjust gcp_username with your email username
```bash
#mv /home/(gcp_username)/auto_restart_gensynAI/create-root.sh /home/(gcp_username)/
mv /home/(gcp_username)/auto_restart_gensynAI/run_rl_swarm.sh /home/(gcp_username)/
```

Delete folder after you copy
```bash
cd && rm -rf auto_restart_gensynAI
```

2. Clone Repository II
```bash
git clone https://github.com/venufitratama/rl-swarm.git
```

```bash
screen -S gensyn
```

```bash
cd rl-swarm
```

```bash
python3 -m venv .venv
source .venv/bin/activate
chmod +x run_rl_swarm.sh
./run_rl_swarm.sh
```

After it Run, you will be asked 2 questions
> Upload to Huggingface Answer `N`
> AI Model Answer `Gensyn/Qwen2.5-0.5B-Instruct`

It the models run, you will see your peerName (3 animal words) and peerID.
Continue the steps

3. Make auto restart

CTRL + A + D to quit from the screen 

```bash
cd && mv -f ~/run_rl_swarm.sh ~/rl-swarm/
```

Get Back inside the screen
```bash
screen -r gensyn
```

```bash
chmod +x run_rl_swarm.sh && ./run_rl_swarm.sh
```
