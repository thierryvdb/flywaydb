# Database Migration GitHub Action

Esta GitHub Action realiza migrações de banco de dados utilizando o Flyway, suportando MySQL e PostgreSQL. Ela pode ser utilizada para automatizar tarefas de migração em ambientes de desenvolvimento, teste e produção.

## Requirements
- **mysql-client - mysql and mysqldump**
- **postgres-client - psql and pg_dump**
- **jq - Interpreting json outputs**
- **docker - Creation of the dummy Database**

## Features

- **Verificação de Conexão com o Banco de Dados**: Verifica a conexão com o banco de dados utilizando as credenciais fornecidas e a URL JDBC.
- **Backup do Banco de Dados**: Cria um backup do esquema do banco de dados.
- **Restauração do Banco de Dados**: Restaura o banco de dados em um ambiente de teste ("dummy") para validação.
- **Migrações Flyway**: Autentica com o Flyway, executa as migrações e gera um relatório detalhado em HTML.
- **Verificação de Variáveis de Ambiente**: Garante que todos os segredos e variáveis necessários estejam configurados antes da execução.

## Usage

Para utilizar esta Action em seus workflows do GitHub, siga as instruções abaixo.

### Exemplo de Workflow

```yaml
name: Flyway Migrations

on:
  pull_request:
    branches:
      - main
      - development
    types:
      - opened
      - synchronize
  workflow_dispatch:
    branches:
      - development


jobs:
  migrate:
    runs-on: ubuntu-latest
    steps:
      - name: Set Proxy Environment Variables
        run: |
          export http_proxy='http://capprxcfwqa.telecom.pt:8080'
          export https_proxy='http://capprxcfwqa.telecom.pt:8080'

      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Database Migration Action
        uses: altp-all/alpt-flywayn@v1
        with:
          DATABASE: ${{ secrets.DATABASE }}
          JDBC: ${{ secrets.JDBC }}
          PASSWORD: ${{ secrets.PASSWORD }}
          USERNAME: ${{ secrets.USERNAME }}
          SCHEMAS: ${{ secrets.SCHEMAS }}
          DIALECT: mysql
          REPO_NAME: ${{ github.event.repository.name }}
          ROOT_PASSWORD: ${{ secrets.ROOT_PASSWORD }}
          FLYWAY_LOCATIONS: "sql/migrations"
          FLYWAY_USER: ${{ secrets.FLYWAY_USER }}
          FLYWAY_PASSWORD: ${{ secrets.FLYWAY_PASSWORD }}
          
```
Inputs and Outputs
```

Inputs

- **DATABASE**: O nome do banco de dados.
- **JDBC**: A string de conexão JDBC para o banco de dados.
- **PASSWORD**: A senha para o banco de dados.
- **USERNAME**: O nome de usuário para o banco de dados.
- **SCHEMAS**: Os esquemas do banco de dados.
- **DIALECT**: O dialeto do banco de dados (ex.: mysql, postgresql).
- **REPO_NAME**: O nome do repositório, usado para nomear containers Docker durante a configuração do ambiente de teste ("dummy").
- **ROOT_PASSWORD**: A senha root para o banco de dados no ambiente de teste.
- **FLYWAY_LOCATIONS**: A(s) localização(ões) onde o Flyway buscará os arquivos de migração.
- **FLYWAY_USER**: O nome de usuário para autenticação com o Flyway.
- **FLYWAY_PASSWORD**: A senha para autenticação com o Flyway.
- **GITHUB_WORKSPACE**: O caminho do workspace do GitHub.


Outputs

- **DBVERSION**: A versão do banco de dados após conectar e verificar.

---

### Funções no `composite`

#### `check_secret()`

Garante que os segredos necessários estejam configurados. Se um segredo estiver ausente, o script será encerrado e fornecerá feedback por meio do resumo da GitHub Action.

---

#### `extract_jdbc_values()`

Extrai informações de conexão (protocolo, host, porta, banco de dados) a partir da URL JDBC fornecida.

---

#### `connect_to_database()`

Tenta se conectar ao banco de dados utilizando as credenciais e a string de conexão JDBC fornecidas. O resultado é registrado no resumo da GitHub Action.

---

#### `get_database_version()`

Recupera e exibe a versão atual do banco de dados.

---

#### `generate_backup()`

Cria um backup do esquema do banco de dados e armazena-o em um arquivo `.dmp`. Os detalhes do backup são registrados no resumo da GitHub Action.

---

#### `restore_to_dummy()`

Restaura o banco de dados a partir do arquivo de backup para um ambiente de teste ("dummy") para fins de validação.

---

#### `flyway_authenticate()`

Autentica com o Flyway utilizando o nome de usuário e a senha fornecidos.

---

#### `run_flyway_migrations_with_report()`

Executa as migrações do Flyway e gera um relatório detalhado.

```
