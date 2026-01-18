# Homelab Documentation

Welcome to my homelab documentation! This site documents my journey of building and managing
a personal Kubernetes homelab cluster for learning, experimentation, and self-hosting various services.

## What is This Homelab?

This homelab is a personal Kubernetes cluster that I use to:

- **Learn** container orchestration and cloud-native technologies
- **Experiment** with different applications and services
- **Self-host** useful tools and applications
- **Practice** DevOps and infrastructure management skills

## Infrastructure Overview

My homelab consists of:

- **Kubernetes Cluster**: Multi-node K8s cluster for container orchestration
- **Harbor Registry**: Private container image registry at `192.168.1.206:30002`
- **Persistent Storage**: For stateful applications and data persistence
- **Networking**: Internal networking and service exposure

## What You'll Find Here

- 🏗️ **[Infrastructure](infrastructure/overview.md)**: Hardware setup, network configuration, and cluster details
- ⚙️ **[Services](services/overview.md)**: Applications and services running in the homelab
- 📚 **[Guides & How-tos](guides/getting-started.md)**: Step-by-step tutorials and deployment guides
- 🔧 **[Troubleshooting](troubleshooting/common-issues.md)**: Solutions to common issues I've encountered
- 📖 **[Reference](reference/configs.md)**: Configuration files, commands, and useful resources
- 🔗 **[Repository](repository/technologies.md)**: Development setup, code quality tools, and project technologies

## Getting Started

If you're interested in setting up something similar, check out the [Getting Started](guides/getting-started.md)
guide to understand the basics of my setup.

For specific deployment scenarios, the [Guides & How-tos](guides/harbor-k8s-deployment.md) section contains
detailed tutorials based on my real-world experience.

---

*This documentation is a living document that evolves as I learn and expand my homelab setup.*
