# nb-levanter
NB Levanter configs and utils

## TPU creation

Check zones for allowed quota

- TPUv4-32 on-demand
```bash
export TPU_NAME=levanter-pod-32
gcloud alpha compute tpus queued-resources create $TPU_NAME --node-id $TPU_NAME --project mimir-411610 --zone us-central2-b --accelerator-type v4-32 --runtime-version tpu-vm-v4-base
```

- TPUv4-32 pre-emptible
```bash
export TPU_NAME=levanter-pod-32-pre
gcloud alpha compute tpus queued-resources create $TPU_NAME --node-id $TPU_NAME --project mimir-411610 --zone us-central2-b --accelerator-type v4-32 --runtime-version tpu-vm-v4-base --best-effortt
```

- Check status
```bash
gcloud alpha compute tpus queued-resources list --zone us-central2-b
```

- Stop pod
```bash
gcloud alpha compute tpus queued-resources stop $TPU_NAME --zone us-central2-b
```

- Delete pod (only stop pods can be deleted)
```bash
gcloud alpha compute tpus queued-resources delete $TPU_NAME --zone us-central2-b
```

## Setup

Locally, download [ttconnect](./ttconnect.sh) to connect to the pod using the `ubuntu` user:
```bash
export TPU_NAME=levanter-pod-32
./ttconnect $TPU_NAME ubuntu
```

Once in the pod, run the next script to install crate a venv, install dependencies, and mount the NFS volume (first line avoids dialog in interactive mode):

```bash
sudo sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
curl -s "https://raw.githubusercontent.com/NbAiLab/nb-levanter/main/infra/helpers/setup-tpu-vm-nfs.sh" | bash
```

Login into Weights and Biases, HuggingFace, and GitHub:
```bash
gh auth login
wandb login
hugginface-cli login
```

Then it's a matter of creating a config in `/share/nb-levanter/configs` and run it in all VMs:
```bash
WANDB_API_KEY=<YOUR KEY HERE> HUGGING_FACE_HUB_TOKEN=$(cat ~/.cache/huggingface/token) levanter/infra/launch.sh python levanter/src/levanter/main/train_lm.py --config_path /share/nb-levanter/configs/mimir-mistral-7b-extended_resume.yaml
```
