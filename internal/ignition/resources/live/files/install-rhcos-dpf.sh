#!/bin/bash

TARGET_DEVICE=/dev/nvme0n1
IGNITION_FILE="/var/target.ign"
DPUFLAVOR_FILE="/etc/dpf/dpuflavor.json"

log() {
    msg="[$(date +%H:%M:%S)] $*"
    echo "$msg"
    echo "$msg" >/dev/kmsg
    /usr/local/bin/bflog.sh "$msg"
}

validate_ignition() {
    if [[ -f "$IGNITION_FILE" ]]; then
        log "INFO: Ignition file found at $IGNITION_FILE"
        if ! jq -e . "$IGNITION_FILE" >/dev/null 2>&1; then
            log "ERROR: Ignition file is not a valid JSON."
            exit 1
        fi
    else
        log "ERROR: Ignition file is missing, skipping installation."
        exit 1
    fi
}

update_ignition() {
    /usr/local/bin/update_ignition.py "$IGNITION_FILE"
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to update ignition file."
        exit 1
    fi
}

setup_RHCOS_EFI_record() {
    # Delete all previous Red Hat CoreOS EFI records
    while efibootmgr -v | grep -q "Red-Hat CoreOS GRUB"; do
        BOOTNUM=$(efibootmgr -v | grep "Red-Hat CoreOS GRUB" | awk '{print $1}' | sed 's/Boot\(....\)\*$/\1/' | head -n1)
        if [[ -n "$BOOTNUM" ]]; then
            efibootmgr -b "$BOOTNUM" -B
            log "INFO: Deleted previous RHCOS EFI record Boot$BOOTNUM"
        else
            break
        fi
    done

    efibootmgr -c -d "$TARGET_DEVICE" -p 2 -l '\EFI\redhat\shimaa64.efi' -L "Red-Hat CoreOS GRUB"
    log "INFO: Created new RHCOS EFI record."
}

install_rhcos() {
    log "INFO: Installing Red Hat CoreOS on $TARGET_DEVICE with ignition file $IGNITION_FILE"

    KERNEL_PARAMETERS="console=hvc0 console=ttyAMA0 earlycon=pl011,0x13010000 ignore_loglevel modprobe.blacklist=mlxbf_pmc"
    FLAVOR_KARGS=$(jq -r .spec.grub.kernelParameters[] $DPUFLAVOR_FILE)

    for param in $FLAVOR_KARGS; do
        case " $KERNEL_PARAMETERS " in
        *" $param "*) ;;
        *) KERNEL_PARAMETERS="$KERNEL_PARAMETERS $param" ;;
        esac
    done

    coreos-installer install "$TARGET_DEVICE" \
        --append-karg "$KERNEL_PARAMETERS" \
        --ignition-file "$IGNITION_FILE" \
        --offline

    if [ $? -ne 0 ]; then
        log "ERROR: Failed to install Red Hat CoreOS."
        exit 1
    fi

    sync
}

wait_for_host_reboot_if_required() {
    for f in /tmp/nvconfig-*.json; do
        [ -f "$f" ] || continue
        local cfg=$(jq '.[].tlv_configuration' "$f")
        local sriov_en=$(echo "$cfg" | jq -r '.SRIOV_EN.next_value')
        local num_of_vfs=$(echo "$cfg" | jq -r '.NUM_OF_VFS.next_value')

        if [ "$sriov_en" != "True(1)" ] || [ "$num_of_vfs" = "0" ]; then
            log "INFO: Host reboot required, signaling host agent"
            /usr/local/bin/dpuagent-client.py update-host-reboot
            log "INFO: Waiting for host reboot..."
            sleep infinity
        fi
    done
    log "INFO: No host reboot required."
}

call_configure_host_vfs() {
    /usr/local/bin/dpuagent-client.py configure-host-vfs
}

validate_ignition
update_ignition

install_rhcos
setup_RHCOS_EFI_record
sync

log "INFO: Installation complete."

wait_for_host_reboot_if_required

call_configure_host_vfs

echo "Waiting for 10 seconds before rebooting"
sleep 10
reboot

# # Hack to skip a reboot after installation
# for i in {1..3}; do
#     /usr/local/bin/bfupsignal.sh
#     sleep 120
# done
