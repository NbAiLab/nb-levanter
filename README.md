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
