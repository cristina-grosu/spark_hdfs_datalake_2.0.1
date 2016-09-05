FROM mcristinagrosu/bigstep_hdfs_datalake

RUN apk add --update alpine-sdk
RUN apk add libffi && apk add jq

# Install Spark 1.6.2
RUN cd /opt && wget http://d3kbcqa49mib13.cloudfront.net/spark-1.6.2-bin-hadoop2.6.tgz
RUN tar xzvf /opt/spark-1.6.2-bin-hadoop2.6.tgz
RUN rm  /opt/spark-1.6.2-bin-hadoop2.6.tgz

# Spark pointers
ENV SPARK_HOME /opt/spark-1.6.2-bin-hadoop2.6
ENV R_LIBS_USER $SPARK_HOME/R/lib
ENV PYTHONPATH $SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.8.2.1-src.zip
ENV SPARK_OPTS --driver-java-options=-Xms1024M --driver-java-options=-Dlog4j.logLevel=info

RUN mv spark-1.6.2-bin-hadoop2.6 /opt/

ADD entrypoint.sh /
ADD core-site.xml.datalake /opt/spark-1.6.2-bin-hadoop2.6/conf/
RUN chmod 777 /entrypoint.sh
ADD spark-defaults.conf /opt/spark-1.6.2-bin-hadoop2.6/conf/spark-defaults.conf.template

ENV HADOOP_HOME /opt/hadoop
ENV HADOOP_CONF_DIR /opt/hadoop/etc/hadoop

ENV CONDA_DIR /opt/conda
ENV PATH $CONDA_DIR/bin:$PATH

RUN cd /opt && \
    wget https://repo.continuum.io/miniconda/Miniconda2-4.1.11-Linux-x86_64.sh && \
     /bin/bash Miniconda2-4.1.11-Linux-x86_64.sh -b -p $CONDA_DIR && \
     rm -rf Miniconda2-4.1.11-Linux-x86_64.sh 

RUN export PATH=$PATH:/$CONDA_DIR/bin

# Install Jupyter notebook 
RUN $CONDA_DIR/bin/conda install --yes \
    'notebook' && \
    $CONDA_DIR/bin/conda clean -yt

#Install Scala Spark kernel
ENV SBT_VERSION 0.13.11
ENV SBT_HOME /usr/local/sbt
ENV PATH ${PATH}:${SBT_HOME}/bin

# Install sbt
RUN curl -sL "http://dl.bintray.com/sbt/native-packages/sbt/$SBT_VERSION/sbt-$SBT_VERSION.tgz" | gunzip | tar -x -C /usr/local && \
    echo -ne "- with sbt $SBT_VERSION\n" >> /root/.built

RUN cd /tmp && \
    curl -sL "http://dl.bintray.com/sbt/native-packages/sbt/$SBT_VERSION/sbt-$SBT_VERSION.tgz" | gunzip | tar -x -C /usr/local && \
    echo -ne "- with sbt $SBT_VERSION\n" >> /root/.built &&\
    git clone https://github.com/apache/incubator-toree.git && \
    cd incubator-toree && \
    git checkout 846292233c && \
    make dist SHELL=/bin/bash && \
    mv dist/toree-kernel /opt/toree-kernel && \
    chmod +x /opt/toree-kernel && \
    rm -rf /tmp/incubator-toree 
    
#Install Python3 packages
RUN $CONDA_DIR/bin/conda install --yes \
    'ipywidgets' \
    'pandas' \
    'matplotlib' \
    'scipy' \
    'seaborn' \
    'scikit-learn' && \
    $CONDA_DIR/bin/conda clean -yt

RUN $CONDA_DIR/bin/conda create --yes -p /opt/conda/envs/python3 python=3.5 ipython ipywidgets pandas matplotlib scipy seaborn scikit-learn
RUN bash -c '. activate python3 && \
    python -m ipykernel.kernelspec --prefix=/opt/conda && \
    . deactivate'
RUN jq --arg v "$CONDA_DIR/envs/python3/bin/python"         '.["env"]["PYSPARK_PYTHON"]=$v' /opt/conda/share/jupyter/kernels/python3/kernel.json > /tmp/kernel.json && \
     mv /tmp/kernel.json /opt/conda/share/jupyter/kernels/python3/kernel.json 

RUN $CONDA_DIR/bin/conda config --add channels r
RUN $CONDA_DIR/bin/conda install --yes -c r r-essentials r-base r-irkernel r-irdisplay r-ggplot2 r-repr r-rcurl
RUN $CONDA_DIR/bin/conda create --yes  -n R -c r r-essentials r-base r-irkernel r-irdisplay r-ggplot2 r-repr r-rcurl

RUN $CONDA_DIR/bin/conda install --yes nb_conda
RUN $CONDA_DIR/bin/python -m nb_conda_kernels.install --disable --prefix=$CONDA_DIR && \
    $CONDA_DIR/bin/conda clean -yt
    
RUN mkdir -p /opt/conda/share/jupyter/kernels/scala
COPY kernel.json /opt/conda/share/jupyter/kernels/scala/

RUN cd /root && wget http://central.maven.org/maven2/com/google/collections/google-collections/1.0/google-collections-1.0.jar

#        SparkMaster  SparkMasterWebUI  SparkWorkerWebUI REST     Jupyter Spark
EXPOSE    7077        8080              8081              6066    8888      4040     88

ENTRYPOINT ["/entrypoint.sh"]
