# Ação GitHub para Migração de Banco de Dados

Esta Ação GitHub facilita migrações de banco de dados usando Flyway. Ela fornece um conjunto de operações para verificar variáveis de ambiente, conectar-se a bancos de dados, executar migrações com Flyway, gerar backups e restaurar bancos de dados em um ambiente dummy.

## Funcionalidades

- **Verificação de Conexão com o Banco de Dados**: Verifica a conexão com o banco de dados usando credenciais e a URL JDBC.
- **Backup do Banco de Dados**: Cria um backup do esquema do banco de dados.
- **Restauração do Banco de Dados**: Restaura o banco de dados para um ambiente dummy para testes.
- **Migrações com Flyway**: Autentica no Flyway, executa migrações e gera um relatório HTML detalhado.
- **Verificação de Variáveis de Ambiente**: Garante que todas as variáveis de ambiente e segredos necessários estejam configurados antes de prosseguir.

## Uso

Para usar esta ação em seus fluxos de trabalho no GitHub, siga as instruções abaixo.

### Exemplo de Workflow

```yaml
name: Migrações com Flyway

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  migrate:
    runs-on: runner
    steps:
      - name: Checkout do código
        uses: actions/checkout@v4

      - name: Executar Ação de Migração de Banco de Dados
        uses: altp-allo/flyway-migration@v1
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
          GITHUB_WORKSPACE: ${{ github.workspace }}
```
Entradas e Saídas
```
Entradas

    DATABASE: O nome do banco de dados.
    JDBC: A string de conexão JDBC para o banco de dados.
    PASSWORD: A senha para o banco de dados.
    USERNAME: O nome de usuário para o banco de dados.
    SCHEMAS: Os esquemas do banco de dados.
    DIALECT: O dialeto do banco de dados (por exemplo, mysql, postgresql).
    REPO_NAME: O nome do repositório, usado para nomear containers Docker durante a configuração do ambiente dummy.
    ROOT_PASSWORD: A senha de root para o banco de dados no ambiente dummy.
    FLYWAY_LOCATIONS: A localização onde o Flyway buscará os arquivos de migração.
    FLYWAY_USER: O nome de usuário para autenticação no Flyway.
    FLYWAY_PASSWORD: A senha para autenticação no Flyway.
    GITHUB_WORKSPACE: O caminho do workspace no GitHub.

Saídas

    DBVERSION: A versão do banco de dados após a conexão e verificação.
```

Funções no entrypoint.sh

```
check_secret()

Garante que os segredos necessários estão configurados. Se um segredo estiver ausente, o script será encerrado e fornecerá feedback por meio do resumo das Ações GitHub.
extract_jdbc_values()

Extrai informações de conexão (protocolo, host, porta, banco de dados) da URL JDBC fornecida.
connect_to_database()

Tenta conectar-se ao banco de dados usando as credenciais fornecidas e a string de conexão JDBC. O resultado é registrado no resumo das Ações GitHub.
get_database_version()

Recupera e exibe a versão atual do banco de dados.
generate_backup()

Cria um backup do esquema do banco de dados e o armazena em um arquivo .dmp. Os detalhes do backup são registrados no resumo das Ações GitHub.
restore_to_dummy()

Restaura o banco de dados a partir do arquivo de backup para um ambiente dummy para testes.
flyway_authenticate()

Autentica no Flyway usando o nome de usuário e a senha fornecidos.
run_flyway_migrations_with_report()

```