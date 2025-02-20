# Flyway Database Migration Action Documentation

## Overview
The **Database Migration Action** is a GitHub Action designed to execute database migrations using **Flyway**. It automates version management across different environments, ensuring integrity and traceability.

## Key Features
- Supports **MySQL**, **PostgreSQL**, and **Oracle** databases
- Schema migration using **Flyway**
- Temporary database creation for testing
- Backup restoration before migration
- Execution support in **QA** and **Production** environments

## Execution Conditioned by PR
The workflow is set to execute migrations only at specific moments:

- **During PR Review:**
  - The workflow runs when a PR is **opened**, **updated**, or **reopened**.
  - At this stage, validations and tests occur only in the **dummy** environment and **QA** environment (if enabled).

- **After Merging to Production:**
  - **Flyway Info and Migration in Production** execute **only after the PR merge** and **only on the `main` branch**.
  - This is enforced by the conditions defined in the workflow:

    ```yaml
    - name: Run Flyway Info on Production
      if: inputs.RUN_ON_PROD == 'true' && github.event.pull_request.merged == true && github.event.pull_request.base.ref == 'main'
    ```
    
    ```yaml
    - name: Run Migration on Production
      if: inputs.RUN_ON_PROD == 'true' && github.event.pull_request.merged == true && github.event.pull_request.base.ref == 'main'
    ```
  
  - This prevents changes from being applied to production before proper review and approval.

## Execution Parameters
The parameters **RUN_ON_PROD** and **RUN_ON_QA** define whether **Flyway Info** and **Migration** will execute in the QA and Production environments.

- By default, both parameters are set to `true`.
- If set to `false`, they prevent execution of **Flyway Info and Migration** steps in these environments.
- In future **Flyway Action** versions or per management decision, this behavior may be adjusted to meet project needs.

## Inputs
| Name | Description | Required | Default |
|------|------------|------------|--------|
| DATABASE | Database name | No | - |
| JDBC | JDBC connection string | Yes | - |
| PASSWORD | Database password | Yes | - |
| USERNAME | Database username | Yes | - |
| QA_JDBC | JDBC connection string (QA) | No | - |
| QA_PASSWORD | Database password (QA) | No | - |
| SCHEMAS | Database schemas | No | "" |
| DIALECT | Database dialect (mysql, postgresql, oracle, etc.) | Yes | - |
| REPO_NAME | Repository name | Yes | - |
| ROOT_PASSWORD | Root password for temporary database | No | - |
| FLYWAY_LOCATIONS | Migration file location | No | migrations |
| FLYWAY_USER | Flyway username | No | - |
| FLYWAY_PASSWORD | Flyway password | No | - |
| FLYWAY_CLI_INSTALL_CHECK | Verify Flyway installation | No | true |
| FLYWAY_VERSION | Flyway version | No | 10.20.1 |
| FLYWAY_INSTALL_DIRECTORY | Flyway CLI installation directory | No | "" |
| OCI_TARGET_TDE_WALLET_ID | Destination TDE Wallet ID | No | - |
| OCI_TARGET_CID | Destination Container OCID | No | - |
| OCI_CLI_USER | OCI-CLI user OCID | No | - |
| OCI_CLI_TENANCY | Tenancy OCID | No | - |
| OCI_CLI_REGION | OCI Region | No | - |
| OCI_CLI_FINGERPRINT | Generated fingerprint | No | - |
| OCI_CLI_KEY_CONTENT | API private key | No | - |
| OCI_PDB_ID | Source PDB ID | No | - |
| OCI_SOURCE_QCARBON_KEY | Source database key | No | - |
| OCI_CDB_ID | Destination CDB ID | No | - |
| RUN_ON_PROD | Execute in Production | No | true |
| RUN_ON_QA | Execute in QA | No | true |

## Workflow Example
```yaml
name: Lint And Flyway Migrations

permissions:
  contents: write
  pull-requests: write

on:
  pull_request:
    types:
      - opened
      - synchronize
      - reopened
    paths:
      - 'migrations/**'

jobs:
  lint-and-migrate:
    runs-on: self-hosted
    steps:
      - name: Set Proxy Environment Variables
        run: |
          export http_proxy='http://capprxcfwqa.telecom.pt:8080'
          export https_proxy='http://capprxcfwqa.telecom.pt:8080'
          export no_proxy="localhost,127.0.0.1,10.0.0.0/8,*.local,*.corppt.com,*.telecom.pt"

      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Database Migration Action
        uses: alpt-all/alpt-flyway@v1
        with:
          JDBC: ${{ secrets.JDBC }}
          PASSWORD: ${{ secrets.PASSWORD }}
          USERNAME: ${{ secrets.USERNAME }}
          DIALECT: oracle
          RUN_ON_PROD: false
          RUN_ON_QA: false
          REPO_NAME: ${{ github.event.repository.name }}
          FLYWAY_USER: ${{ secrets.FLYWAY_USER }}
          FLYWAY_PASSWORD: ${{ secrets.FLYWAY_PASSWORD }}
```

## Conclusion
This Action enables a highly automated and secure database migration flow, ensuring consistency and integrity in deployment processes.

