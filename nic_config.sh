#!/usr/bin/env bash
#
# ===============================================================================
# NIC Configuration Script for Network Benchmarking
# ===============================================================================
#
# Description:
#   This script configures a network interface card (NIC) for optimal performance
#   during network benchmarking. It handles CPU isolation, NIC queue configuration,
#   and IRQ affinity to ensure consistent and reliable benchmark results.
#
# Features:
#   - Sets CPU scaling governor to performance mode
#   - Configures NIC queue counts and sizes
#   - Pins IRQs to specific CPU cores
#   - Configures Receive/Transmit Packet Steering (RPS/XPS)
#   - Saves default settings for easy restoration
#
# Usage:
#   Apply settings:   ./nic_config.sh apply
#   Revert settings:  ./nic_config.sh revert
#
# Requirements:
#   - Root privileges
#   - ethtool and cpupower utilities
#   - systemd for managing irqbalance service
#
# Kernel Parameters (recommended):
#   To isolate cores from the Linux scheduler, add to kernel command line:
#   isolcpus=<CPU_LIST> nohz_full=<CPU_LIST> rcu_nocbs=<CPU_LIST>
#   For example: "isolcpus=120-127 nohz_full=120-127 rcu_nocbs=120-127"
#
# Author: Zhiyi Sun (with the help of GitHub Copilot)
# Last Modified: May 8, 2025
#
# ===============================================================================

# ====== CONFIGURABLE VARIABLES ======
NUM_CORES=${NUM_CORES:-8}
CPU_LIST=${CPU_LIST:-"0-$((NUM_CORES-1))"}
IFACE=${IFACE:-eth0}
COMBINED_QUEUES=${COMBINED_QUEUES:-$NUM_CORES}
QUEUE_SIZE=${QUEUE_SIZE:-8192}
DEFAULTS_FILE=${DEFAULTS_FILE:-"/var/tmp/nic_benchmark.defaults"}

# ====== DETECT PCI BUS INFO ======
# Use ethtool to get the PCI bus-info for the interface
PCIE_BUS=$(ethtool -i "$IFACE" | awk '/bus-info:/ {print $2}')
# Escape slashes for use in grep
PCIE_BUS_ESCAPED=$(echo "$PCIE_BUS" | sed 's|/|\\/|g')

# ====== HELPER FUNCTION TO GENERATE HEX MASK ======
# Reads an existing mask file to determine segment count,
# then produces a comma-separated hex mask for the specified CPU_LIST.
function generate_hex_mask() {
  local cpu_list="$1"
  local mask_file="$2"
  # read original segments to get count
  IFS=',' read -ra orig <<< "$(cat "$mask_file")"
  local seg_count=${#orig[@]}
  local -a mask_arr=( $(for ((i=0; i<seg_count; i++)); do echo 0; done) )

  # expand CPU_LIST entries
  IFS=',' read -ra entries <<< "$cpu_list"
  for entry in "${entries[@]}"; do
    if [[ "$entry" == *-* ]]; then
      IFS='-' read -r start end <<< "$entry"
      for ((c=start; c<=end; c++)); do
        local idx=$((c/32))
        local bit=$((c%32))
        mask_arr[$idx]=$((mask_arr[$idx] | (1 << bit)))
      done
    else
      local c=$entry
      local idx=$((c/32))
      local bit=$((c%32))
      mask_arr[$idx]=$((mask_arr[$idx] | (1 << bit)))
    fi
  done

  # build hex string MSB-first (segmentN-1,...,segment0)
  local mask_str=""
  for ((i=seg_count-1; i>=0; i--)); do
    mask_str+=$(printf "%08x" "${mask_arr[i]}")
    [[ $i -ne 0 ]] && mask_str+=','
  done
  echo "$mask_str"
}

# ====== SAVE CURRENT SETTINGS ======
function save_defaults() {
  echo "Saving current settings to $DEFAULTS_FILE..."
  {
    echo "IRQBALANCE_ENABLED=$(systemctl is-enabled irqbalance.service 2>/dev/null)"
    echo "COMBINED_QUEUES=$(ethtool -l $IFACE | awk '/Combined:/ {print $2}')"
    echo "RX_RING_SIZE=$(ethtool -g $IFACE | awk '/RX:/ {print $2}' | head -n1)"
    echo "TX_RING_SIZE=$(ethtool -g $IFACE | awk '/TX:/ {print $2}' | head -n1)"
    echo "IRQ_AFFINITY="
    # Filter interrupts by Mellanox PCI ID and mlx5_comp prefix
    grep -E "mlx5_comp[0-9]+@pci:${PCIE_BUS_ESCAPED}" /proc/interrupts | \
      while read -r irq rest; do
        val=$(cat /proc/irq/${irq%:}/smp_affinity_list)
        echo "  $irq:$val"
      done
    echo "RPS_MASKS="
    for f in /sys/class/net/$IFACE/queues/rx-*/rps_cpus; do
      echo "  $f: $(cat $f)"
    done
    echo "XPS_MASKS="
    for f in /sys/class/net/$IFACE/queues/tx-*/xps_cpus; do
      echo "  $f: $(cat $f)"
    done
  } > "$DEFAULTS_FILE"
  echo "Defaults saved."
}

# ====== REVERT TO SAVED SETTINGS ======
function revert_defaults() {
  if [[ ! -f $DEFAULTS_FILE ]]; then
    echo "No defaults file found at $DEFAULTS_FILE. Cannot revert." >&2
    exit 1
  fi
  echo "Reverting settings from $DEFAULTS_FILE..."
  source "$DEFAULTS_FILE"
  # irqbalance
  if [[ $IRQBALANCE_ENABLED == "enabled" ]]; then
    systemctl enable irqbalance.service
    systemctl start irqbalance.service
  else
    systemctl stop irqbalance.service
    systemctl disable irqbalance.service
  fi
  # queues & rings
  ethtool -L $IFACE combined $COMBINED_QUEUES
  ethtool -G $IFACE rx $RX_RING_SIZE tx $RX_RING_SIZE
  # irq affinity
  grep -E "^[[:space:]]*[0-9]+:" "$DEFAULTS_FILE" | \
    while IFS=":" read -r irq mask; do
      echo "$mask" > /proc/irq/$irq/smp_affinity_list
    done
  # RPS/XPS
  grep -E "/rps_cpus:" "$DEFAULTS_FILE" | \
    while IFS=":" read -r file mask; do
      echo "$mask" > "$file"
    done
  grep -E "/xps_cpus:" "$DEFAULTS_FILE" | \
    while IFS=":" read -r file mask; do
      echo "$mask" > "$file"
    done
  echo "Revert complete."
}

# ====== APPLY NEW SETTINGS ======
function apply_settings() {
  scaling_governor
  # Not available in Ubuntu 24.04
#  stop_irqbalance
  set_ethtool_queues
  set_ring_buffers
  pin_irqs
  configure_rps_xps
}

function scaling_governor() {
  cpupower frequency-set -r -g performance
}

function disable_cstate() {
  cpupower idle-set -d 2
}

function stop_irqbalance() {
  echo "Stopping irqbalance..."
  systemctl stop irqbalance.service
  systemctl.disable irqbalance.service
}

function set_ethtool_queues() {
  echo "Setting $IFACE combined queues to $COMBINED_QUEUES..."
  ethtool -L $IFACE combined $COMBINED_QUEUES
}

function set_ring_buffers() {
  echo "Setting RX/TX ring buffer sizes to $QUEUE_SIZE..."
  ethtool -G $IFACE rx $QUEUE_SIZE tx $QUEUE_SIZE
}

function pin_irqs() {
  echo "Pinning IRQs for $IFACE (bus $PCIE_BUS) to CPUs $CPU_LIST..."
  # only target interrupts from our Mellanox device
  local IRQ_LIST=$(grep -E "mlx5_comp[0-9]+@pci:${PCIE_BUS_ESCAPED}" /proc/interrupts | cut -d: -f1)
  for irq in $IRQ_LIST; do
    echo "$CPU_LIST" > /proc/irq/$irq/smp_affinity_list
  done
}

function configure_rps_xps() {
  echo "Configuring RPS and XPS for $IFACE..."
  for f in /sys/class/net/$IFACE/queues/rx-*/rps_cpus; do
    local hex_mask=$(generate_hex_mask "$CPU_LIST" "$f")
    echo "$hex_mask" > "$f"
  done
  for f in /sys/class/net/$IFACE/queues/tx-*/xps_cpus; do
    local hex_mask=$(generate_hex_mask "$CPU_LIST" "$f")
    echo "$hex_mask" > "$f"
  done
}

# ====== ENTRYPOINT ======
case "$1" in
  apply)
    save_defaults
    apply_settings
    ;;
  revert)
    revert_defaults
    ;;
  *)
    echo "Usage: $0 {apply|revert}" >&2
    exit 1
    ;;
esac

