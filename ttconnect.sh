#!/bin/bash
# Modified from https://github.com/peregilk/ttconnect to take in user names

# Set default zone if not provided
zone=${3:-us-central2-b}
name=$1
user=${2:-$USER}

# Check if the name argument is provided
if [ -z "$name" ]; then
    echo "Usage: $0 NAME [USER=$USER] [ZONE=us-central2-b]"
    exit 1
fi

echo "Connecting to $name in zone $zone";

# Some basic checks if the input is valid
output=$(gcloud compute tpus describe $name --zone $zone 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Could not find a tpu-v4 with the name $name in the zone $zone. Exiting."
    exit 1
fi

# Extracting TPU type and size without quotes
tputype=$(echo $output | awk '{print $2}')
tpusize=$(echo $tputype | cut -c4-)
size=$(($tpusize / 8))

if (( size < 1 )); then
    echo "This is reported as a $tputype with $size tpu(s). This is not a valid tpu-v4 resource. Exiting."
    exit 1
fi

# Check if the tmux session exists, if not create it
# If there is already a session with this name, it will just attach
tmux has-session -t $name 2>/dev/null

if [ $? != 0 ]; then
        tmux new-session -d -s $name
        tmux select-layout main-horizontal

        for i in $(seq $(($size-1))); do
                tmux split-window -v -d -t $name
                # Making sure there is space to split
                tmux select-layout main-horizontal
        done

        for i in $(seq $(($size))); do
                worker=$(($i -1))
                #command="gcloud alpha compute tpus tpu-vm ssh $name --zone $zone --worker $worker"
                command="gcloud alpha compute tpus tpu-vm ssh "$user@$name" --zone $zone --tunnel-through-iap --worker $worker"
                tmux select-pane -t $name:0.$worker
                tmux send-keys -t $name "$command" Enter

        done

        # Select the final layout
        if ((size >= 16));then
                tmux select-layout tiled
        else
                tmux select-layout tiled
                tmux select-layout main-horizontal
        fi

        # Enable mouse control - for changing pane size
        # Disabled for now since it makes copying more difficult
        # tmux set-mouse on

        # Move cursor to worker 0
        tmux select-pane -t $name:0.0

        # Resize the left window
        tmux resize-pane -L 50



        # Set pane synchronization
        tmux set-window-option -t $name:0 synchronize-panes on

        # Set pane border format
        tmux set-option -t $name pane-border-status top
        tmux set-option -t $name pane-border-format "worker #{pane_index} "


fi

# Attach to the session
tmux attach -t $name

