# ./jupyter/Dockerfile
# FROM --platform=linux/arm64 python:3.9-slim-bullseye
FROM python:3.9-slim-bullseye

LABEL maintainer="jorgegarciaflores@gmail.com"


ENV DEBIAN_FRONTEND=noninteractive
ENV HADOOP_VERSION=3.3.1
ENV HADOOP_HOME=/opt/hadoop
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-arm64
ENV PATH=$PATH:$JAVA_HOME/bin

# instalar dependencias de sistema (jdk, wget, tar, build tools para compilar Wheels si hiciera falta)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      openjdk-11-jdk-headless \
      wget \
      curl \
      gnupg \
      ca-certificates \
      build-essential \
      default-jdk \
      ssh \
      rsync \
      procps \
      git \
      unzip \
      locales \
      gcc \
      g++ \
      libssl-dev \
      libffi-dev \
      python3-dev \
      && rm -rf /var/lib/apt/lists/*

# locale (opcional pero útil)
RUN sed -i '/es_ES.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen

# instalar Hadoop 3.3.1 (binario)
RUN mkdir -p /opt && \
    cd /opt && \
    wget -q https://archive.apache.org/dist/hadoop/common/hadoop-3.3.1/hadoop-3.3.1.tar.gz && \
    tar -xzf hadoop-3.3.1.tar.gz && \
    mv hadoop-3.3.1 ${HADOOP_HOME} && \
    rm hadoop-3.3.1.tar.gz


# pip + jupyter + kernels
RUN python -m pip install --upgrade pip setuptools wheel
RUN python -m pip install \
    jupyterlab \
    notebook \
    ipykernel \
    jupyter \
    numpy \
    pandas \
    mrjob \
    avro-python3

# crear kernel con nombre claro
# USER ${NB_USER}
# RUN python -m ipykernel install --user --name jupyter_hadoop_py39 --display-name "Python (jupyter_hadoop_py39)"

# # Exponer puerto jupyter (uso 8888 dentro)
# EXPOSE 8888

# # Volumen por defecto para notebooks
# VOLUME ["/home/jovyan/notebooks", "/dataset"]

# Config Jupyter: sin token (solo para entornos de laboratorio controlados)
# RUN mkdir -p /home/jovyan/.jupyter && \
#     echo "c.NotebookApp.token = ''" >> /home/jovyan/.jupyter/jupyter_notebook_config.py && \
#     echo "c.NotebookApp.password = ''" >> /home/jovyan/.jupyter/jupyter_notebook_config.py && \
#     echo "c.NotebookApp.ip = '0.0.0.0'" >> /home/jovyan/.jupyter/jupyter_notebook_config.py && \
#     echo "c.NotebookApp.open_browser = False" >> /home/jovyan/.jupyter/jupyter_notebook_config.py

RUN mkdir /app

#Instalamos: MariaDB server (compatible con MySQL) para el metastore de Hive. Dsdmainutils para herramienta hexdump
RUN apt-get -q update && \
    apt-get -q install -y mariadb-server bsdmainutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
      
# Desactivación autentificación Jupyter Notebooks
RUN mkdir -p /root/.jupyter && \
    touch /root/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.token = ''" >> /root/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.password = ''" >> /root/.jupyter/jupyter_notebook_config.py


#Instalación Apache Hive 3.1.2
#RUN wget https://ftp.cixug.es/apache/hive/hive-3.1.2/apache-hive-3.1.2-bin.tar.gz && \
RUN wget https://archive.apache.org/dist/hive/hive-3.1.2/apache-hive-3.1.2-bin.tar.gz && \
    tar -xvzf apache-hive-3.1.2-bin.tar.gz -C /app && \
    rm apache-hive-3.1.2-bin.tar.gz && \
    rm /app/apache-hive-3.1.2-bin/lib/log4j-slf4j-impl-2.10.0.jar
ENV HIVE_HOME=/app/apache-hive-3.1.2-bin
ENV HCAT_HOME=$HIVE_HOME/hcatalog
ENV PATH=$PATH:$HIVE_HOME/bin
COPY /hiveconf/hive-site.xml $HIVE_HOME/conf/
COPY /hiveconf/hcat_server.sh $HIVE_HOME/hcatalog/sbin/
COPY /hiveconf/mysql-connector-java-8.0.23.jar $HIVE_HOME/lib/


#Instalación Apache Pig
RUN wget https://ftp.cixug.es/apache/pig/pig-0.17.0/pig-0.17.0.tar.gz && \
    tar -xvzf pig-0.17.0.tar.gz -C /app && \
    rm pig-0.17.0.tar.gz 	 
ENV PIG_HOME=/app/pig-0.17.0
ENV PATH=$PATH:$PIG_HOME/bin

#Instalación Apache Flume 1.9.0
## RUN wget https://ftp.cixug.es/apache/flume/1.9.0/apache-flume-1.9.0-bin.tar.gz && \
RUN wget https://archive.apache.org/dist/flume/1.9.0/apache-flume-1.9.0-bin.tar.gz && \
    tar -xvzf apache-flume-1.9.0-bin.tar.gz -C /app && \
    rm apache-flume-1.9.0-bin.tar.gz && \
    rm /app/apache-flume-1.9.0-bin/lib/guava-11.0.2.jar #incompatible con versión en hadoop
ENV FLUME_HOME=/app/apache-flume-1.9.0-bin
ENV PATH=$PATH:$FLUME_HOME/bin


#Instalación Apache Sqoop 
## RUN wget https://ftp.cixug.es/apache/sqoop/1.4.7/sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz && \
RUN wget https://archive.apache.org/dist/sqoop/1.4.7/sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz && \
    tar -xvzf sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz -C /app && \
    rm sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz && \ 	
    cp $HIVE_HOME/lib/hive-common-3.1.2.jar $HIVE_HOME/lib/commons-lang-2.6.jar /app/sqoop-1.4.7.bin__hadoop-2.6.0/lib 
ENV SQOOP_HOME=/app/sqoop-1.4.7.bin__hadoop-2.6.0
ENV PATH=$PATH:$SQOOP_HOME/bin


#Instalación MrJob y avro-python
RUN pip install mrjob avro-python3

#Copiamos datasets
COPY ./dataset /dataset

#Formateo HDFS
RUN mkdir -p /hdfs/namenode && \
    hdfs namenode -format

# Iniciar MariaDB en modo seguro (sin systemd) y ejecutar los comandos
# RUN mysqld_safe --skip-networking & sleep 5 && \
#     mysql -u root -e "CREATE USER 'hive'@'localhost' IDENTIFIED BY 'ubigdata';" && \
#     mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'hive'@'localhost';" && \
#     mysql -u root -e "FLUSH PRIVILEGES;" && \
#     schematool -dbType mysql -initSchema

# RUN mkdir -p /run/mysqld && chown -R mysql:mysql /run/mysqld
# RUN mysql_install_db --user=mysql --ldata=/var/lib/mysql
# RUN mysqld --skip-networking --socket=/run/mysqld/mysqld.sock & \
#     sleep 10 && \
#     mysql -u root --socket=/run/mysqld/mysqld.sock -e "CREATE USER 'hive'@'localhost' IDENTIFIED BY 'ubigdata';" && \
#     mysql -u root --socket=/run/mysqld/mysqld.sock -e "GRANT ALL PRIVILEGES ON *.* TO 'hive'@'localhost';" && \
#     schematool -dbType mysql -initSchema
# # startup
# CMD ["jupyter", "notebook", "--no-browser", "--port=8888", "--ip=0.0.0.0", "--NotebookApp.token=''", "--NotebookApp.password=''"]

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 9870 8889 10002



