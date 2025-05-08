# iperf3_performance_suite

A comprehensive suite of tools for network performance benchmarking using iperf3, designed to measure throughput and CPU utilization under various conditions.

## Overview

This suite consists of scripts for both the client and server sides to thoroughly benchmark network performance. It includes tools for:

- NIC configuration optimization for benchmarking
- Network throughput measurement with multiple parallel threads
- CPU utilization monitoring during benchmarks
- Client-side CPU performance analysis

## System Requirements

- Linux operating system
- iperf3 installed on both client and server
- ethtool and cpupower utilities
- Root privileges for NIC configuration
- sysstat package (for mpstat utility on the server)

## Directory Structure

```
iperf3_performance_suite/
├── README.md             # This file
├── LICENSE               # License information
├── nic_config.sh         # NIC configuration script for both client and server
├── client/
│   ├── network_throughput_test.sh    # Client script for throughput testing
│   └── client_cpu_benchmark.sh       # Client script for CPU utilization testing
└── server/
    └── server_cpu_monitor.sh         # Server script for CPU monitoring
```

## Setup Instructions

1. Clone this repository on both client and server machines:
   ```
   git clone <repository-url>
   cd iperf3_performance_suite
   ```

2. Make all scripts executable:
   ```
   chmod +x nic_config.sh
   chmod +x client/*.sh
   chmod +x server/*.sh
   ```

3. Configure NICs for optimal performance on both client and server:
   ```
   sudo ./nic_config.sh apply
   ```
   
   This will:
   - Set CPU scaling governor to performance mode
   - Configure NIC queue counts and sizes
   - Pin IRQs to specific CPU cores
   - Configure Receive/Transmit Packet Steering (RPS/XPS)

## Testing Scenarios

### 1. Network Throughput Test

This test measures the maximum achievable bandwidth between client and server using multiple parallel threads.

**Server side:**
1. Start iperf3 in server mode:
   ```
   iperf3 -s -i 0
   ```

**Client side:**
1. Run the throughput test script:
   ```
   ./client/network_throughput_test.sh
   ```
   
   The script will:
   - Test with varying numbers of parallel threads (1, 2, 4, 8, 16, 32, 64)
   - Perform multiple iterations of each test
   - Use CPU affinity to control which cores run the tests
   - Implement cool-down periods between test runs

### 2. CPU Utilization Test

This test measures CPU utilization on both server and client while running network tests.

**Server side:**
1. Start iperf3 in server mode:
   ```
   iperf3 -s -i 0
   ```

2. Run the CPU monitoring script:
   ```
   ./server/server_cpu_monitor.sh
   ```
   
   This script monitors CPU utilization on cores 96-127 with 1-second intervals.

**Client side:**
1. Run the CPU benchmark script:
   ```
   ./client/client_cpu_benchmark.sh
   ```
   
   The script will:
   - Test with multiple thread counts (1, 2, 4, 8, 16, 32, 64)
   - Use CPU affinity to control which cores run the tests
   - Implement cool-down periods between test runs

## Restoring NIC Configuration

After testing is complete, restore the original NIC configuration on both client and server:

```
sudo ./nic_config.sh revert
```

## Notes

- The default server IP in the client scripts is set to 192.168.2.1. Modify this in the scripts if your server has a different IP address.
- For optimal results, ensure no other network-intensive applications are running during tests.
- The scripts use specific CPU core ranges (e.g., 64-127 for client tests, 96-127 for server monitoring). Adjust these values in the scripts according to your system's CPU configuration.

## Author

Zhiyi Sun (with the help of GitHub Copilot)  
Last Modified: May 8, 2025