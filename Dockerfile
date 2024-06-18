# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
ARG BASE_CONTAINER=jupyter/scipy-notebook
FROM $BASE_CONTAINER

LABEL maintainer="Jupyter Project <jupyter@googlegroups.com>"

# Fix DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# Dependencias spark
ENV APACHE_SPARK_VERSION=3.5.1 \
    HADOOP_VERSION=3
# variaveis locais hadoop
ENV HADOOP_HOME /usr/local/hadoop-${HADOOP_VERSION}
ENV HADOOP_CONF_DIR /etc/hadoop
ENV HADOOP_HDFS_USER hdfs
ARG GLIBC_APKVER=2.27-r0
ARG GOSU_VERSION=1.10

# hadoop variaveis de ambiente
ENV HADOOP_OPTS -Djava.net.preferIPv4Stack=true
ENV HADOOP_PORTMAP_OPTS -Xmx512m
ENV HADOOP_CLIENT_OPTS -Xmx512m

# instalacao do jdk 11
RUN apt-get -y update && \
    apt-get install --no-install-recommends -y openjdk-11-jre-headless ca-certificates-java && \
    rm -rf /var/lib/apt/lists/*

# especificacao do diretorio para consertar problema com download do spark
WORKDIR /tmp

# Passo 1: diretamente especifica a URL
RUN echo "https://downloads.apache.org/spark/spark-${APACHE_SPARK_VERSION}/spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" > spark_url && \
    cat spark_url

# Passo 2: Checa o conteudo da spark url
RUN echo "Content of spark_url:" && cat spark_url

# Passo 3: Download dos arquivos adicionais com verificacoes
RUN URL=$(cat spark_url) && \
    echo "Downloading Spark from $URL" && \
    wget --spider $URL && \
    wget -q -O spark.tgz $URL && \
    if [ -f spark.tgz ]; then echo "File downloaded successfully"; else echo "File not downloaded"; exit 1; fi && \
    ls -lh spark.tgz

# Passo 4: Verifica checksum
RUN echo "3d8e3f082c602027d540771e9eba9987f8ea955e978afc29e1349eb6e3f9fe32543e3d3de52dff048ebbd789730454c96447c86ff5b60a98d72620a0f082b355 *spark.tgz" | sha512sum -c -

# Passo 4: Extrai arquivos
RUN tar xzf spark.tgz -C /usr/local --owner root --group root --no-same-owner && \
    rm spark.tgz spark_url

WORKDIR /usr/local
RUN ln -s "spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}" spark

# Passo 5: Configura spark
ENV SPARK_HOME=/usr/local/spark
ENV PYTHONPATH=$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.9-src.zip \
    SPARK_OPTS="--driver-java-options=-Xms1024M --driver-java-options=-Xmx4096M --driver-java-options=-Dlog4j.logLevel=info" \
    PATH=$PATH:$SPARK_HOME/bin

# Step 6: Instala requerimentos
USER $NB_UID
COPY requirements.txt /tmp/
# instala pip no conda
RUN conda install --yes pip
# instala dependencias no conda
RUN conda install --yes pyspark && \
    conda install --yes numpy && \
    conda install --yes seaborn && \
    conda install --yes matplotlib && \
    conda install --yes pandas
# instala dependencias no python
RUN python -m pip install -r /tmp/requirements.txt

# Instala pyarrow
RUN conda install --quiet -y 'pyarrow' && \
    conda clean --all -f -y && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

WORKDIR $HOME
