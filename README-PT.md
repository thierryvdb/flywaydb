# Documentação da Flyway Database Migration Action

## Visão Geral
A **Database Migration Action** é uma Ação do GitHub projetada para executar migrações de banco de dados utilizando o **Flyway**. Ela permite automatizar a gestão de versões do banco de dados em diferentes ambientes, garantindo integridade e rastreabilidade.

## Funcionalidades Principais
- Suporte a bancos de dados **MySQL**, **PostgreSQL** e **Oracle**
- Migração de esquemas utilizando **Flyway**
- Criação de banco de dados temporário para testes
- Restauração de backup antes da migração
- Suporte à execução em ambientes **QA** e **Produção**

## Execução Condicionada por PR
O workflow está configurado para executar as migrações apenas em momentos específicos:

- **Durante a revisão do PR:**
  - O workflow será executado quando um PR for **aberto**, **atualizado** ou **reaberto**.
  - Nesse estágio, as validações e testes são feitos apenas no ambiente **dummy** e no ambiente **QA** (caso esteja ativado).

- **Após o Merge para Produção:**
  - A execução do **Flyway Info e Migration em Produção** ocorre **somente após o merge do PR** e **apenas na branch `main`**.
  - Isso é garantido pelas condições definidas no workflow:

    ```yaml
    - name: Run Flyway Info on Production
      if: inputs.RUN_ON_PROD == 'true' && github.event.pull_request.merged == true && github.event.pull_request.base.ref == 'main'
    ```
    
    ```yaml
    - name: Run Migration on Production
      if: inputs.RUN_ON_PROD == 'true' && github.event.pull_request.merged == true && github.event.pull_request.base.ref == 'main'
    ```

  - Assim, evita-se que mudanças sejam aplicadas em produção antes de uma revisão e aprovação adequada.

## Parâmetros de Execução
Os parâmetros **RUN_ON_PROD** e **RUN_ON_QA** são utilizados para definir se a execução do **Flyway Info** e **Migration** ocorrerá nos ambientes QA e Produção.

- Por padrão, ambos os parâmetros possuem o valor `true`.
- Se configurados como `false`, impedirão a execução dos passos relacionados ao **Flyway Info e Migration** nesses ambientes.
- Em versões futuras da **Flyway Action** ou conforme decisão da gestão, esse comportamento poderá ser ajustado para atender às necessidades do projeto.

## Entradas
| Nome | Descrição | Obrigatório | Padrão |
|------|------------|------------|--------|
| DATABASE | Nome do banco de dados | Não | - |
| JDBC | String de conexão JDBC | Sim | - |
| PASSWORD | Senha do banco de dados | Sim | - |
| USERNAME | Usuário do banco de dados | Sim | - |
| QA_JDBC | String de conexão JDBC (QA) | Não | - |
| QA_PASSWORD | Senha do banco de dados (QA) | Não | - |
| SCHEMAS | Esquemas do banco de dados | Não | "" |
| DIALECT | Dialeto do banco de dados (mysql, postgresql, oracle, etc.) | Sim | - |
| REPO_NAME | Nome do repositório | Sim | - |
| ROOT_PASSWORD | Senha root para banco de dados em ambiente temporário | Não | - |
| FLYWAY_LOCATIONS | Localização dos arquivos de migração | Não | migrations |
| FLYWAY_USER | Usuário do Flyway | Não | - |
| FLYWAY_PASSWORD | Senha do Flyway | Não | - |
| FLYWAY_CLI_INSTALL_CHECK | Verificar instalação do Flyway | Não | true |
| FLYWAY_VERSION | Versão do Flyway | Não | 10.20.1 |
| FLYWAY_INSTALL_DIRECTORY | Diretório de instalação do Flyway CLI | Não | "" |
| OCI_TARGET_TDE_WALLET_ID | ID da Wallet TDE de destino | Não | - |
| OCI_TARGET_CID | OCID do Container de destino | Não | - |
| OCI_CLI_USER | OCID do usuário para manipulação via OCI-CLI | Não | - |
| OCI_CLI_TENANCY | OCID do Tenancy | Não | - |
| OCI_CLI_REGION | Região OCI | Não | - |
| OCI_CLI_FINGERPRINT | Fingerprint gerado | Não | - |
| OCI_CLI_KEY_CONTENT | Chave privada da API | Não | - |
| OCI_PDB_ID | ID do PDB de origem | Não | - |
| OCI_SOURCE_QCARBON_KEY | Chave do banco de dados de origem | Não | - |
| OCI_CDB_ID | ID do CDB de destino | Não | - |
| RUN_ON_PROD | Executar na Produção | Não | true |
| RUN_ON_QA | Executar no QA | Não | true |

## Exemplo de Workflow
```yaml
name: Flyway Migrations

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
        with:
          clean: true

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

## Conclusão
Esta Ação permite um fluxo de migração de banco de dados altamente automatizado e seguro, garantindo consistência e integridade nos processos de deploy.

