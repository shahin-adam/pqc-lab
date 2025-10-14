# PQC Lab 🔐

A portable Docker environment for experimenting with **Post-Quantum Cryptography (PQC)** algorithms using [liboqs](https://github.com/open-quantum-safe/liboqs) and Python bindings.

## ✨ Features
- Builds liboqs with **Kyber**, **Dilithium**, **SPHINCS+**, and more
- Runs benchmarks and produces CSV/PNG reports
- Fully containerized (Docker) — works on any machine
- Extensible Python scripts for KEMs and signatures

## 🐳 Quick Start
```bash
docker build -t pqc-lab .
docker run --rm -it -v "$PWD":/app pqc-lab
