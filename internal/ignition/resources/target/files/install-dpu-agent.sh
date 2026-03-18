#!/bin/bash

exec > >(tee >(while read -r line; do /usr/local/bin/bflog.sh "$line"; done)) 2>&1

echo "Installing dpu-agent..."

while true; do
    if ping -6 -c1 -W1 fe80::1%tmfifo_net0 &>/dev/null; then
        break
    else
        echo "Waiting for connectivity to host agent via tmfifo_net0..."
        sleep 1
    fi
done



cd /tmp
dnf download dpu-agent &&
  rpm2cpio dpu-agent*.rpm | cpio -idm --no-absolute-filenames &&
  mv opt/dpf/dpuagent /usr/local/bin/dpu-agent &&
  restorecon /usr/local/bin/dpu-agent
