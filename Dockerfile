# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
ARG BASE_CONTAINER=jupyter/scipy-notebook
FROM $BASE_CONTAINER

LABEL maintainer="Jupyter Project <jupyter@googlegroups.com>"

# Fix DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# Spark dependencies
ENV APACHE_SPARK_VERSION=3.5.1 \
    HADOOP_VERSION=3

RUN apt-get -y update && \
    apt-get install --no-install-recommends -y openjdk-11-jre-headless ca-certificates-java && \
    rm -rf /var/lib/apt/lists/*

# Using a fixed mirror to download Spark
WORKDIR /tmp

# Step 1: Directly specify the URL
RUN echo "https://downloads.apache.org/spark/spark-${APACHE_SPARK_VERSION}/spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" > spark_url && \
    cat spark_url

# Step 2: Check the content of spark_url
RUN echo "Content of spark_url:" && cat spark_url

# Step 3: Download the file with additional checks
RUN URL=$(cat spark_url) && \
    echo "Downloading Spark from $URL" && \
    wget --spider $URL && \
    wget -q -O spark.tgz $URL && \
    if [ -f spark.tgz ]; then echo "File downloaded successfully"; else echo "File not downloaded"; exit 1; fi && \
    ls -lh spark.tgz

# Step 4: Verify the checksum
RUN echo "3d8e3f082c602027d540771e9eba9987f8ea955e978afc29e1349eb6e3f9fe32543e3d3de52dff048ebbd789730454c96447c86ff5b60a98d72620a0f082b355 *spark.tgz" | sha512sum -c -

# Step 5: Extract the file
RUN tar xzf spark.tgz -C /usr/local --owner root --group root --no-same-owner && \
    rm spark.tgz spark_url

WORKDIR /usr/local
RUN ln -s "spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}" spark

# Configure Spark
ENV SPARK_HOME=/usr/local/spark
ENV PYTHONPATH=$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.9-src.zip \
    SPARK_OPTS="--driver-java-options=-Xms1024M --driver-java-options=-Xmx4096M --driver-java-options=-Dlog4j.logLevel=info" \
    PATH=$PATH:$SPARK_HOME/bin

# Step 6: Install requirements
USER $NB_UID
COPY requirements.txt /tmp/
RUN python -m pip install -r /tmp/requirements.txt

# Install pyarrow
RUN conda install --quiet -y 'pyarrow' && \
    conda clean --all -f -y && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

WORKDIR $HOME
