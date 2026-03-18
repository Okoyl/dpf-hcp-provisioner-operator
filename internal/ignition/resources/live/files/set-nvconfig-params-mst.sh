#!/bin/bash
set -e

nvconfig_params=$(jq -r '.spec.nvconfig[].parameters[]' /etc/dpf/dpuflavor.json | tr '\n' ' ')
if [ -z "$nvconfig_params" ]; then
  echo "No nvconfig parameters found in /etc/dpf/dpuflavor.json"
  exit 1
fi

pcie_dev_list=$(lspci -d 15b3: | grep ConnectX | awk '{print $1}')

for dev in ${pcie_dev_list}; do
  echo "Saving NVConfig query results to /tmp/nvconfig-${dev}.json"
  mstconfig -d ${dev} -j /tmp/nvconfig-${dev}.json query

  echo "Setting NVConfig on dev ${dev}: ${nvconfig_params}"
  mstconfig -d ${dev} -y set ${nvconfig_params}
done

echo "Finished setting nvconfig parameters"
