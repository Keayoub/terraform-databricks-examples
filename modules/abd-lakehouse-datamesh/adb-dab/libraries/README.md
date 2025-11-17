# Library Management Guide

This guide covers how to manage Python, R, and JVM libraries for your domain-specific Databricks workspace.

## Directory Structure

```
libraries/
├── data-science-requirements.txt      # ML and Bio libraries
├── data-engineering-requirements.txt  # ETL and data processing libraries
└── README.md                          # This file

init-scripts/
└── bio-dependencies.sh                # System-level bioinformatics tools
```

## Installation Methods

### 1. Cluster Libraries (Terraform)

Install libraries when cluster is created:

```hcl
resource "databricks_library" "biopython" {
  cluster_id = databricks_cluster.my_cluster.id
  pypi {
    package = "biopython>=1.81"
  }
}
```

### 2. Notebook-Scoped Installation

Install libraries at runtime in notebooks:

```python
# Install single package
%pip install biopython==1.81

# Install from requirements file
%pip install -r /Volumes/amrnet_catalog/ml/configs/requirements.txt

# Upgrade existing package
%pip install --upgrade scikit-learn

# Install with specific version
%pip install numpy==1.24.3
```

### 3. Init Scripts

For system-level dependencies, use init scripts:

```hcl
resource "databricks_cluster" "bio_cluster" {
  # ... other config ...
  
  init_scripts {
    workspace {
      destination = "/init-scripts/bio-dependencies.sh"
    }
  }
}
```

### 4. Requirements File in Volumes

Store and version control requirements:

```bash
# Upload requirements file
databricks fs cp data-science-requirements.txt \
  dbfs:/Volumes/amrnet_catalog/ml/configs/requirements.txt

# In notebook, install from volume
%pip install -r /Volumes/amrnet_catalog/ml/configs/requirements.txt
```

## Library Recommendations by Role

### Data Engineers

**Core Libraries:**
- `pandas>=2.0.0` - Data manipulation
- `pyarrow>=10.0.0` - Arrow format support
- `delta-spark>=2.4.0` - Delta Lake operations
- `great-expectations>=0.17.0` - Data quality
- `azure-storage-blob>=12.0.0` - Azure Storage integration

**ETL Tools:**
- `dbt-databricks>=1.6.0` - dbt transformations
- `sqlalchemy>=2.0.0` - SQL toolkit
- `psycopg2-binary>=2.9.0` - PostgreSQL connector

### Data Scientists

**Machine Learning:**
- `scikit-learn>=1.3.0` - Traditional ML
- `xgboost>=2.0.0` - Gradient boosting
- `lightgbm>=4.0.0` - Light GBM
- `mlflow>=2.8.0` - Experiment tracking
- `hyperopt>=0.2.7` - Hyperparameter tuning

**Deep Learning:**
- `tensorflow>=2.13.0` - TensorFlow
- `torch>=2.0.0` - PyTorch
- `transformers>=4.30.0` - Hugging Face transformers
- `sentence-transformers>=2.2.0` - Sentence embeddings

**Bioinformatics:**
- `biopython>=1.81` - Biological computation
- `numpy>=1.24.0` - Numerical computing
- `scipy>=1.11.0` - Scientific computing
- `networkx>=3.1` - Graph analysis

**Model Interpretability:**
- `shap>=0.42.0` - SHAP values
- `lime>=0.2.0` - Local interpretability

**Visualization:**
- `matplotlib>=3.7.0` - Static plots
- `seaborn>=0.12.0` - Statistical visualizations
- `plotly>=5.17.0` - Interactive plots

### BI Readers

BI readers typically use SQL Warehouses and don't install custom libraries. They rely on:
- Built-in Databricks SQL functions
- Standard SQL operations
- Pre-built dashboards

## Maven/JAR Libraries

For Scala/Java dependencies:

```hcl
resource "databricks_library" "delta_core" {
  cluster_id = databricks_cluster.my_cluster.id
  maven {
    coordinates = "io.delta:delta-core_2.12:2.4.0"
  }
}

resource "databricks_library" "hadoop_azure" {
  cluster_id = databricks_cluster.my_cluster.id
  maven {
    coordinates = "org.apache.hadoop:hadoop-azure:3.3.4"
  }
}
```

## R Packages (CRAN)

For R users:

```hcl
resource "databricks_library" "ggplot2" {
  cluster_id = databricks_cluster.my_cluster.id
  cran {
    package = "ggplot2"
  }
}
```

In notebooks:
```r
install.packages("BiocManager")
BiocManager::install("Biostrings")
```

## Best Practices

### 1. Version Pinning

Always pin versions for production:

```txt
# ❌ Bad - no version specified
pandas

# ✅ Good - version pinned
pandas==2.0.3

# ✅ Also good - minimum version with compatibility
pandas>=2.0.0,<3.0.0
```

### 2. Requirements File Organization

Create separate requirements files:

```
libraries/
├── requirements-base.txt          # Common to all roles
├── requirements-ml.txt            # ML-specific
├── requirements-bio.txt           # Bioinformatics
└── requirements-dev.txt           # Development tools
```

### 3. Reproducibility

Document library versions in:
- Cluster tags: `Libraries: pandas==2.0.3, scikit-learn==1.3.0`
- Git repository with requirements.txt
- MLflow runs for ML experiments

### 4. Security

Scan libraries for vulnerabilities:

```bash
# Install safety
pip install safety

# Check for known vulnerabilities
safety check -r requirements.txt
```

### 5. Performance Optimization

**Pre-warm clusters:**
- Use init scripts for commonly-used libraries
- Create instance pools with pre-installed libraries
- Consider custom Docker images for heavy dependencies

**Minimize installation time:**
```python
# Install multiple packages in one command
%pip install pandas numpy scikit-learn

# Use --no-deps to skip dependency resolution (if already installed)
%pip install --no-deps mypackage
```

## Bioinformatics-Specific Setup

### System Dependencies

The `bio-dependencies.sh` init script installs:
- BLAST (sequence alignment)
- SAMtools (sequence analysis)
- BEDtools (genomic interval operations)
- BWA & Bowtie2 (sequence alignment)

### Python Bio Libraries

```python
# Core bioinformatics
from Bio import SeqIO
from Bio.Seq import Seq
from Bio.SeqRecord import SeqRecord

# Sequence analysis
import pysam
import pybedtools

# Visualization
import matplotlib.pyplot as plt
import seaborn as sns
```

### Working with Genomic Data

```python
# Read FASTA files from Unity Catalog volumes
fasta_path = "/Volumes/amrnet_catalog/raw/landing/sequences.fasta"
sequences = list(SeqIO.parse(fasta_path, "fasta"))

# Process and save to Delta table
import pandas as pd
df = pd.DataFrame([
    {"id": str(seq.id), "sequence": str(seq.seq), "length": len(seq.seq)}
    for seq in sequences
])
df.write.format("delta").mode("overwrite").saveAsTable("amrnet_catalog.raw.sequences")
```

## Troubleshooting

### Issue: "Library conflicts"

```python
# Create isolated environment
%pip install --no-deps package_name

# Or restart Python kernel
dbutils.library.restartPython()
```

### Issue: "ImportError after installation"

```python
# Restart Python to reload libraries
dbutils.library.restartPython()
```

### Issue: "Slow library installation"

Use cluster libraries instead of notebook-scoped installation for frequently-used packages.

### Issue: "Package not found in PyPI"

Install from Git or wheel file:

```python
# From Git
%pip install git+https://github.com/username/repo.git

# From wheel file in volume
%pip install /Volumes/amrnet_catalog/ml/wheels/custom_package-1.0.0-py3-none-any.whl
```

## Example: Complete ML Setup

```python
# Install all ML and bio libraries
%pip install -r /Volumes/amrnet_catalog/ml/configs/requirements.txt

# Restart Python to load new libraries
dbutils.library.restartPython()

# Import and verify
import biopython
import sklearn
import mlflow
print(f"BioPython: {biopython.__version__}")
print(f"Scikit-learn: {sklearn.__version__}")
print(f"MLflow: {mlflow.__version__}")
```

## Maintenance

### Update Libraries

```bash
# Generate new requirements file with updated versions
pip freeze > requirements-updated.txt

# Upload to volume
databricks fs cp requirements-updated.txt \
  dbfs:/Volumes/amrnet_catalog/ml/configs/requirements.txt
```

### Audit Library Usage

```sql
-- Track library usage via cluster tags
SELECT 
  cluster_id,
  cluster_name,
  custom_tags['Libraries'] as installed_libraries
FROM system.compute.clusters
WHERE custom_tags['Domain'] = 'amrnet';
```

## Additional Resources

- [Databricks Libraries Documentation](https://docs.databricks.com/libraries/index.html)
- [BioPython Tutorial](https://biopython.org/wiki/Documentation)
- [Python Package Index (PyPI)](https://pypi.org/)
- [Maven Repository](https://mvnrepository.com/)
- [CRAN Repository](https://cran.r-project.org/)
