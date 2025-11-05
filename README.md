# terraform-databricks-examples

This repository contains the following:

- Multiple examples of Databricks workspace and resources deployment on Azure, AWS and GCP using [Databricks Terraform provider](https://registry.terraform.io/providers/databricks/databricks/latest/docs).
- Examples of implementing CI/CD pipelines to automate your Terraform deployments using Azure DevOps or GitHub Actions.

- [terraform-databricks-examples](#terraform-databricks-examples)
  - [Using the repository](#using-the-repository)
  - [Repository structure](#repository-structure)
  - [Repository content](#repository-content)
    - [Examples](#examples)
    - [Modules](#modules)
    - [CI/CD pipelines](#cicd-pipelines)
  - [Contributing](#contributing)

## Using the repository

There are two ways to use this repository:

1. Use examples as a reference for your own Terraform code: Please refer to `examples` folder for individual examples.
2. Reuse modules from this repository: Please refer to `modules` folder.

## Repository structure

Code in the repository is organized into the following folders:

- `modules` - implementation of specific Terraform modules.
- `examples` - specific instances that use Terraform modules.
- `cicd-pipelines` - Detailed examples of implementing CI/CD pipelines to automate your Terraform deployments using Azure DevOps or GitHub Actions.

## Repository content

> **Note**  
> For detailed information about the examples, modules, or CI/CD pipelines, refer to `README.md` file inside the corresponding folder for a detailed guide on setting up the CI/CD pipeline.

### Examples

The folder `examples` contains the following Terraform implementation examples :

| Cloud | Example                                                                            | Description                                                                                                                                                   |
| ----- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|Azure | [adb-lakehouse](examples/adb-lakehouse/)         | Lakehouse terraform blueprints|
| Azure | [adb-with-private-link-standard](examples/adb-with-private-link-standard/)         | Provisioning Databricks on Azure with Private Link - [Standard deployment](https://learn.microsoft.com/en-us/azure/databricks/administration-guide/cloud-configurations/azure/private-link-standard) |
| Azure | [adb-vnet-injection](examples/adb-vnet-injection/)                                 | A basic example of VNet injected Azure Databricks workspace                                                                                                                                          |
| Azure | [adb-exfiltration-protection](examples/adb-exfiltration-protection/)               | A sample implementation of [Data Exfiltration Protection](https://www.databricks.com/blog/2020/03/27/data-exfiltration-protection-with-azure-databricks.html)                                        |
| Azure | [adb-external-hive-metastore](examples/adb-external-hive-metastore/)               | Example template to implement [external hive metastore](https://learn.microsoft.com/en-us/azure/databricks/data/metastores/external-hive-metastore)                                                  |
| Azure | [adb-kafka](examples/adb-kafka/)                                                   | ADB - single node kafka template                                                                                                                                                                     |
| Azure | [adb-private-links](examples/adb-private-links/)                                   | Azure Databricks Private Links                                                                                                                                                                       |
| Azure | [adb-squid-proxy](examples/adb-squid-proxy/)                                       | ADB clusters with HTTP proxy                                                                                                                                                                         |
| Azure | [adb-teradata](examples/adb-teradata/)                                             | ADB with single VM Teradata integration                                                                                                                                                              |
| Azure | [adb-uc](examples/adb-uc/)                                                         | ADB Unity Catalog Process                                                                                                                                                                            |
| Azure | [adb-unity-catalog-basic-demo](examples/adb-unity-catalog-basic-demo/)             | ADB Unity Catalog end-to-end demo including UC metastore setup, Users/groups sync from AAD to databricks account, UC Catalog, External locations, Schemas, & Access Grants                           |
| Azure | [adb-overwatch](examples/adb-overwatch/)             | Overwatch multi-workspace deployment on Azure                          |
            
### Modules

The folder `modules` contains the following Terraform modules :

| Cloud | Module                                                                                                    | Description                                                                                                                                                                               |
| ----- |-----------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| All   | [databricks-department-clusters](modules/databricks-department-clusters/)                                 | Terraform module that creates Databricks resources for a team                                                                                                                             |
| Azure | [adb-lakehouse](modules/adb-lakehouse/)                                                                   | Lakehouse terraform blueprints                                                                                                                                                            |
| Azure | [adb-lakehouse-uc](modules/adb-lakehouse-uc/)                                                             | Provisioning Unity Catalog resources and accounts principals                                                                                                                              |
| Azure | [adb-with-private-link-standard](modules/adb-with-private-link-standard/)                                 | Provisioning Databricks on Azure with Private Link - Standard deployment                                                                                                                  |
| Azure | [adb-exfiltration-protection](modules/adb-exfiltration-protection/)                                       | A sample implementation of [Data Exfiltration Protection](https://www.databricks.com/blog/2020/03/27/data-exfiltration-protection-with-azure-databricks.html)                             |
| Azure | [adb-with-private-links-exfiltration-protection](modules/adb-with-private-links-exfiltration-protection/) | Provisioning Databricks on Azure with Private Link and [Data Exfiltration Protection](https://www.databricks.com/blog/2020/03/27/data-exfiltration-protection-with-azure-databricks.html) |
| Azure | [adb-overwatch-regional-config](modules/adb-overwatch-regional-config/)                                   | Overwatch regional configuration on Azure                                                                                                                                                 |
| Azure | [adb-overwatch-mws-config](modules/adb-overwatch-mws-config/)                                             | Overwatch multi-workspace deployment on Azure                                                                                                                                             |
| Azure | [adb-overwatch-main-ws](modules/adb-overwatch-main-ws/)                                                   | Main Overwatch workspace deployment                                                                                                                                                       |
| Azure | [adb-overwatch-ws-to-monitor](modules/adb-overwatch-ws-to-monitor/)                                       | Overwatch deployment on the Azure workspace to monitor                                                                                                                                    |
| Azure | [adb-overwatch-analysis](modules/adb-overwatch-analysis/) | Overwatch analysis notebooks Deployment on Azure |

### CI/CD pipelines

The `cicd-pipelines` folder contains the following implementation examples of pipeline:

| Tool           | CI/CD Pipeline                                                                           |
| -------------- | ---------------------------------------------------------------------------------------- |
| GitHub Actions | [manual-approve-with-github-actions](cicd-pipelines/manual-approve-with-github-actions/) |
| Azure DevOps   | [manual-approve-with-azure-devops](cicd-pipelines/manual-approve-with-azure-devops/)     |

## Contributing

When contributing the new code, please follow the structure described in the [Repository content](#repository-content) section:

* The reusable code should go into the `modules` directory to be easily included when it's published to the Terraform registry.  Prefer to implement the modular design consisting of multiple smaller modules implementing a specific functionality vs. one big module that does everything.  For example, a separate module for Unity Catalog objects could be used across all clouds, so we won't need to reimplement the same functionality in cloud-specific modules.
* Provide examples of module usage in the `examples` directory - it should show how to use the given module(s).
