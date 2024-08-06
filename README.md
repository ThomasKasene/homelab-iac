# Homelab Infrastructure as Code

This repository is a playground for me to learn about various technologies such as Linux, Raspberry Pi, and K3S. It's not currently stable and you shouldn't use it.

## Raspberry Pi K3S Cluster

### Prerequisites

Each node in the Raspberry Pi K3S cluster to be flashed with the following settings:

- Raspberry Pi OS Lite (64-bit)
- A unique hostname
- SSH enabled

Additionally, all nodes must have a reserved IP on the network so they can reliably be addressed from the automation found in this repository.
