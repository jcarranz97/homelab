# Getting Started

Welcome to my homelab! This guide will help you understand how to navigate and use this documentation.

## What is a Homelab?

A homelab is a personal testing environment where you can:

- Learn new technologies safely
- Test configurations before production
- Self-host applications and services
- Practice system administration skills

## My Homelab Setup

My homelab is centered around a Kubernetes cluster that runs various services and applications. The main components include:

- **Kubernetes Cluster**: Container orchestration platform
- **Harbor Registry**: Private container image registry
- **Persistent Storage**: For stateful applications
- **Networking**: Service mesh and ingress controllers

## Documentation Structure

This documentation is organized into several sections:

### 📋 Infrastructure

Describes the physical and logical infrastructure:

- Hardware specifications
- Network topology
- Kubernetes cluster configuration

### ⚙️ Services

Documents all running services:

- Service descriptions and access information
- Configuration details
- Integration points

### 📚 Guides & How-tos

Step-by-step tutorials for:

- Deploying applications
- Configuring services
- Troubleshooting common issues

### 🔧 Troubleshooting

Common problems and their solutions

### 📖 Reference

Quick reference materials:

- Configuration files
- Useful commands
- External resources

## How to Use This Documentation

1. **New to homelabs?** Start with the [Infrastructure Overview](../infrastructure/overview.md) to understand the setup

2. **Want to deploy something?** Check the [Guides & How-tos](harbor-k8s-deployment.md) section for detailed tutorials

3. **Looking for a specific service?** Visit the [Services](../services/overview.md) section

4. **Having issues?** Check [Troubleshooting](../troubleshooting/common-issues.md) for solutions

## Prerequisites

To follow along with the guides in this documentation, you should have:

- Basic understanding of containers and Docker
- Familiarity with Kubernetes concepts
- Access to a Kubernetes cluster (or willingness to set one up)
- Command line experience with `kubectl`

## Contributing

This is my personal documentation, but if you find errors or have suggestions, feel free to reach out!

## Next Steps

Ready to dive in? Here are some suggested paths:

- **Infrastructure Tour**: [Infrastructure Overview](../infrastructure/overview.md)
- **First Deployment**: [Harbor & K8s Deployment Guide](harbor-k8s-deployment.md)
- **Service Catalog**: [Services Overview](../services/overview.md)
