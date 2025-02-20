# Use Oracle Linux with the Instant Client as the base image
FROM ghcr.io/oracle/oraclelinux8-instantclient:21

COPY prxcfwqa.telecom.pt.crt /etc/pki/ca-trust/source/anchors/

RUN update-ca-trust

RUN export http_proxy='http://capprxcfwqa.telecom.pt:8080'
RUN export https_proxy='http://capprxcfwqa.telecom.pt:8080'
RUN export no_proxy="localhost,127.0.0.1,10.0.0.0/8,*.local,*.corppt.com,*.telecom.pt"

# Install Oracle Instant Client tools and SQL*Plus
RUN yum install -y oracle-instantclient-sqlplus oracle-instantclient-tools && \
    yum clean all

# Set environment variables
ENV ORACLE_HOME=/usr/lib/oracle/21/client64
ENV PATH=$ORACLE_HOME/bin:$PATH
ENV LD_LIBRARY_PATH=$ORACLE_HOME/lib

# Add a default command to keep the container running
CMD ["tail", "-f", "/dev/null"]