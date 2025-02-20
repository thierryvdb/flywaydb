FROM ubuntu:22.04

# Instalar ferramentas que as lógicas precisam
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    jq \
    mysql-client \
    postgresql-client \
    iputils-ping \
    netcat \
    openssl \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*


# Ensure the latest CA certificates are used
RUN update-ca-certificate

# Set Python Trusted Certificates
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt


# Install Flyway CLI
RUN wget -qO- https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/10.20.1/flyway-commandline-10.20.1-linux-x64.tar.gz | tar xvz \
    && ln -s /flyway-10.20.1/flyway /usr/local/bin/flyway

# Install OCI CLI (Ensuring Python trusts the repositories)
RUN curl -L -O https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh \
    && chmod +x install.sh \
    && ENV PIP_TRUSTED_HOSTS="--trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org" ./install.sh --accept-all-defaults \
    && rm install.sh

# Upgrade pip and ensure trusted hosts are used
RUN pip install --upgrade pip $PIP_TRUSTED_HOSTS   

# Instalar kubectl
RUN curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
 && echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list \
 && apt-get update \
 && apt-get install -y kubectl \
 && rm -rf /var/lib/apt/lists/*

# Copia todos os entrypoints
COPY Scripts/entrypoint.sh /entrypoint.sh
COPY Scripts/entrypoint-mysql.sh /entrypoint-mysql.sh
COPY Scripts/entrypoint-postgres.sh /entrypoint-postgres.sh
COPY Scripts/entrypoint-oracle.sh /entrypoint-oracle.sh

# Dá permissão de execução
RUN chmod +x /entrypoint.sh \
    /entrypoint-mysql.sh \
    /entrypoint-postgres.sh \
    /entrypoint-oracle.sh

ENTRYPOINT ["/entrypoint.sh"]
