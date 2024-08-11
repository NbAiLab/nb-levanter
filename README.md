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

Once in the pod, run the next script to create a venv, install dependencies, and mount the NFS volume (first line avoids dialog in interactive mode):

```bash
curl -s "https://raw.githubusercontent.com/NbAiLab/nb-levanter/main/infra/helpers/setup-tpu-vm-nfs.sh" | bash
```

Or this other other one if NFS is not needed:

```bash
curl -s "https://raw.githubusercontent.com/NbAiLab/nb-levanter/main/infra/helpers/setup-tpu-vm.sh" | bash
```

Optionally, mount an NFS volume:
```bash
sudo apt-get -qq install -y nfs-common
export NFS_SERVER=10.63.96.66
export MOUNT_POINT="/share"
sudo mkdir -p ${MOUNT_POINT}
export CURRENT_NFS_ENTRY=$(grep ${NFS_SERVER} /etc/fstab)
export DESIRED_NFS_ENTRY="${NFS_SERVER}:/share ${MOUNT_POINT} nfs defaults 0 0"
grep -v "${NFS_SERVER}" /etc/fstab > /tmp/fstab.new
echo "${DESIRED_NFS_ENTRY}" >> /tmp/fstab.new
sudo cp /etc/fstab /etc/fstab.orig
sudo mv /tmp/fstab.new /etc/fstab
sudo mount -a
```

Optionally, login into Weights and Biases, HuggingFace, and GitHub:
```bash
gh auth login
wandb login
hugginface-cli login
```

## Training

Then it's a matter of creating a config in `/share/nb-levanter/configs` or a GCP bucket and run it in all VMs:
```bash
WANDB_API_KEY=<YOUR KEY HERE> HF_TOKEN=$(cat ~/.cache/huggingface/token) levanter/infra/launch.sh python levanter/src/levanter/main/train_lm.py --config_path /share/nb-levanter/configs/mimir-mistral-7b-extended.yaml
```

For resuming, you can create an extra config file os just invoke the same command but passing in a couple of extra parameters, `--trainer.wandb.resume true --trainer.id <WANDB_ID>`

## Troubleshooting

1. If getting a `BarrierTimeoutException: DEADLINE_EXCEEDED: Barrier timed out` when writing checkpoints, try setting `TENSORSTORE_CURL_LOW_SPEED_TIME_SECONDS=360 TENSORSTORE_CURL_LOW_SPEED_LIMIT_BYTES=256` to force retry.
2. When processing very long documents, Ray might get OOM or fail to start or finish tokenization/cahing of the dataset. In this case, it might help to reduce the number of CPUs so the global memory is not exhausted with `SLURM_CPUS_ON_NODE=16 TOKENIZERS_PARALLELISM=false`. 
3. Some options for optimization (untested): `LIBTPU_INIT_ARGS='--xla_jf_spmd_threshold_for_windowed_einsum_mib=0 --xla_tpu_spmd_threshold_for_allgather_cse=10000 --xla_enable_async_all_gather=true --xla_tpu_enable_latency_hiding_scheduler=true TPU_MEGACORE=MEGACORE_DENSE'`
4. Add `--trainer.fsdp_axis=null` for smaller models (below 1B).
