# Adapted from https://github.com/stanford-crfm/levanter/blob/main/infra/helpers/setup-tpu-vm-nfs.sh
if [ "$DEBUG" == "1" ]; then
  set -x
fi

# we frequently deal with commands failing, and we like to loop until they succeed. this function does that for us
function retry {
  for i in {1..5}; do
    $@
    if [ $? -eq 0 ]; then
      break
    fi
    if [ $i -eq 5 ]; then
      >&2 echo "Error running $*, giving up"
      exit 1
    fi
    >&2 echo "Error running $*, retrying in 5 seconds"
    sleep 5
  done
}

# tcmalloc interferes with intellij remote ide
sudo patch -f -b /etc/environment << EOF
2c2
< LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libtcmalloc.so.4"
---
> #LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libtcmalloc.so.4"
EOF

# don't complain if already applied
retCode=$?
[[ $retCode -le 1 ]] || exit $retCode

ulimit -n 65535
sudo sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf

# set these env variables b/c it makes tensorstore behave better
if ! grep -q TENSORSTORE_CURL_LOW_SPEED_TIME_SECONDS /etc/environment; then
  # need sudo
  echo "TENSORSTORE_CURL_LOW_SPEED_TIME_SECONDS=60" | sudo tee -a /etc/environment > /dev/null
fi

if ! grep -q TENSORSTORE_CURL_LOW_SPEED_LIMIT_BYTES /etc/environment; then
  echo "TENSORSTORE_CURL_LOW_SPEED_LIMIT_BYTES=1024" | sudo tee -a /etc/environment > /dev/null
fi

# install python 3.10, latest git
sudo systemctl stop unattended-upgrades  # this frequently holds the apt lock
sudo systemctl disable unattended-upgrades
#sudo apt remove -y unattended-upgrades
# if it's still running somehow, kill it
if [ $(ps aux | grep unattended-upgrade | wc -l) -gt 1 ]; then
  sudo kill -9 $(ps aux | grep unattended-upgrade | awk '{print $2}')
fi

# sometimes apt-get update fails, so retry a few times
retry sudo apt-get install -y software-properties-common
retry sudo add-apt-repository -y ppa:deadsnakes/ppa
retry sudo add-apt-repository -y ppa:git-core/ppa
retry sudo apt-get -qq update
retry sudo apt-get -qq install -y python3.10-full python3.10-dev git

# set up nfs
retry sudo apt-get -qq install -y nfs-common
NFS_SERVER=10.63.96.66
MOUNT_POINT="/share"
sudo mkdir -p ${MOUNT_POINT}
CURRENT_NFS_ENTRY=$(grep ${NFS_SERVER} /etc/fstab)
DESIRED_NFS_ENTRY="${NFS_SERVER}:/share ${MOUNT_POINT} nfs defaults 0 0"
# if different, fix
if [ "$CURRENT_NFS_ENTRY" != "$DESIRED_NFS_ENTRY" ]; then
  set -e
  echo "Setting up nfs"
  grep -v "${NFS_SERVER}" /etc/fstab > /tmp/fstab.new
  echo "${DESIRED_NFS_ENTRY}" >> /tmp/fstab.new
  # then move the new fstab back into place
  sudo cp /etc/fstab /etc/fstab.orig
  sudo mv /tmp/fstab.new /etc/fstab
fi
sudo mount -a

# Install GitHub client CLI
(type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
&& sudo mkdir -p -m 755 /etc/apt/keyrings \
&& wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
&& sudo apt update \
&& sudo apt install gh -y
for x in `ls -d /share/lev*`; do
  git config --global --add safe.directory $x
done

# symlink lev* to home
ln -s /share/lev* ~

VENV=~/venvs/levanter
# if the venv doesn't exist, make it
if [ ! -d "$VENV" ]; then
    echo "Creating virtualenv at $VENV"
    python3.10 -m venv $VENV
fi

source $VENV/bin/activate

pip install -U pip
pip install -U wheel

# jax and jaxlib
# libtpu sometimes has issues installing for clinical (probably firewall?)
#retry pip install -U "jax[tpu]==0.4.5" libtpu-nightly==0.1.dev20230216 -f https://storage.googleapis.com/jax-releases/libtpu_releases.html
retry pip install -U "jax[tpu]==0.4.21" -f https://storage.googleapis.com/jax-releases/libtpu_releases.html

# install levanter
cd levanter
git fetch --all
pip install -e .

# default to loading the venv
sudo bash -c "echo \"source ${VENV}/bin/activate\" > /etc/profile.d/activate_shared_venv.sh"

