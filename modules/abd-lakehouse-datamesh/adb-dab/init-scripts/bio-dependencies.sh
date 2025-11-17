#!/bin/bash
# ====================================================================================================
# Bioinformatics Dependencies Init Script
# ====================================================================================================
# This init script installs system-level dependencies required for bioinformatics workloads.
# It runs on cluster startup before Spark initialization.
#
# Usage: Attach to cluster via init_scripts block in Terraform
# ====================================================================================================

set -ex

echo "Installing system dependencies for bioinformatics..."

# Update package manager
apt-get update -y

# Install essential build tools
apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl

# Install bioinformatics tools
apt-get install -y \
    ncbi-blast+ \
    samtools \
    bedtools \
    bwa \
    bowtie2

# Install additional scientific libraries
apt-get install -y \
    libopenblas-dev \
    liblapack-dev \
    gfortran \
    libhdf5-dev

# Install R and bioinformatics packages (optional)
# apt-get install -y r-base r-base-dev
# Rscript -e "install.packages('BiocManager', repos='https://cloud.r-project.org')"
# Rscript -e "BiocManager::install(c('Biostrings', 'GenomicRanges'))"

# Install additional Python system dependencies
apt-get install -y \
    python3-dev \
    python3-pip \
    python3-setuptools

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "Bioinformatics dependencies installation completed!"
