# Homelab Documentation

Welcome to my personal Kubernetes homelab documentation repository! This project documents my journey of building
and managing a container orchestration environment for learning, experimentation, and self-hosting services.

## 🌐 Live Documentation

**📖 [View Documentation](https://jcarranz97.github.io/homelab/)**

The complete documentation is automatically deployed using GitHub Pages and available at:
**<https://jcarranz97.github.io/homelab/>**

## 🏗️ What is This Homelab?

This homelab is a personal Kubernetes cluster used for:

- **Learning** container orchestration and cloud-native technologies
- **Experimenting** with different applications and services
- **Self-hosting** useful tools and applications
- **Practicing** DevOps and infrastructure management skills

## 📋 Infrastructure Overview

Current setup includes:

- **Kubernetes Cluster**: Multi-node K8s cluster for container orchestration
- **Harbor Registry**: Private container image registry at `192.168.1.206:30002`
- **Persistent Storage**: For stateful applications and data persistence
- **Networking**: Internal networking and service exposure

## 📚 Documentation Structure

The documentation covers:

- 🏗️ **Infrastructure**: Hardware setup, network configuration, and cluster details
- ⚙️ **Services**: Applications and services running in the homelab
- 📚 **Guides & How-tos**: Step-by-step tutorials and deployment guides
- 🔧 **Troubleshooting**: Solutions to common issues encountered
- 📖 **Reference**: Configuration files, commands, and useful resources

## 🚀 Getting Started

Visit the [live documentation](https://jcarranz97.github.io/homelab/) to explore:

1. **[Getting Started Guide](https://jcarranz97.github.io/homelab/guides/getting-started/)** -
   Understand the basics of the setup
2. **[Harbor K8s Deployment](https://jcarranz97.github.io/homelab/guides/harbor-k8s-deployment/)** -
   Real-world deployment tutorial
3. **[Infrastructure Overview](https://jcarranz97.github.io/homelab/infrastructure/overview/)** -
   Detailed infrastructure documentation

## 🛠️ Development

This documentation is built with:

- **[MkDocs Material](https://squidfunk.github.io/mkdocs-material/)** - Modern documentation theme
- **GitHub Actions** - Automated deployment pipeline
- **GitHub Pages** - Free static site hosting

### Local Development

```bash
# Install dependencies
pip install mkdocs-material

# Serve locally
mkdocs serve

# Build static site
mkdocs build
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

*This documentation is a living document that evolves as I learn and expand my homelab setup.*
