#!/bin/bash

SPARK_HOME="/opt/spark-1.6.2-bin-hadoop2.6"

echo Using SPARK_HOME=$SPARK_HOME

. "${SPARK_HOME}/sbin/spark-config.sh"

. "${SPARK_HOME}/bin/load-spark-env.sh"

export JAVA_HOME="/opt/jdk"                                                                                                                               
export PATH="$PATH:/opt/jdk/bin:/opt/jdk/jre/bin"
export HADOOP_HOME="/opt/hadoop"
export PATH="$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin"
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
export HADOOP_PREFIX="$HADOOP_HOME"
export HADOOP_SBIN_DIR="$HADOOP_HOME/sbin"
export HADOOP_SBIN_DIR="$HADOOP_HOME/bin"
export HADOOP_CLASSPATH="$HADOOP_HOME/share/hadoop/common/"
export JAVA_CLASSPATH="$JAVA_HOME/jre/lib/"
export JAVA_OPTS="-Dsun.security.krb5.debug=true"

rm -rf /opt/hadoop/etc/hadoop/core-site.xml

if [ "$HDFS_MASTER" != "" ]; then
	sed "s/HOSTNAME/$HDFS_MASTER/" /opt/hadoop/etc/hadoop/core-site.xml.template >> /opt/hadoop/etc/hadoop/core-site.xml
fi
if [ "$DATALAKE_USER" != "" ]; then
	sed "s/DATALAKE_USER/$DATALAKE_USER/" /opt/hadoop/etc/hadoop/core-site.xml >> /opt/hadoop/etc/hadoop/core-site.xml.tmp && \
	mv /opt/hadoop/etc/hadoop/core-site.xml.tmp /opt/hadoop/etc/hadoop/core-site.xml
fi
if [ "$KEYTAB_PATH" != "" ]; then
	sed "s/KEYTAB_PATH/${KEYTAB_PATH}/" /opt/hadoop/etc/hadoop/core-site.xml >> /opt/hadoop/etc/hadoop/core-site.xml.tmp && \
	mv /opt/hadoop/etc/hadoop/core-site.xml.tmp /opt/hadoop/etc/hadoop/core-site.xml
fi
if [ "$USER_HOME_DIR" != "" ]; then
	sed "s/USER_HOME_DIR/$USER_HOME_DIR/" /opt/hadoop/etc/hadoop/core-site.xml >> /opt/hadoop/etc/hadoop/core-site.xml.tmp && \
	mv /opt/hadoop/etc/hadoop/core-site.xml.tmp /opt/hadoop/etc/hadoop/core-site.xml
fi
if [ "$CONTAINER_DIR" != "" ]; then
	cp $CONTAINER_DIR/datalake-1.1-SNAPSHOT.jar $HADOOP_CLASSPATH 
    	cp $CONTAINER_DIR/datalake-1.1-SNAPSHOT.jar $JAVA_CLASSPATH
    	cp $CONTAINER_DIR/.k5keytab $KEYTAB_PATH_URI
fi


if [ "$SPARK_MASTER_PORT" = "" ]; then
  SPARK_MASTER_PORT=7077
fi
if [ "$SPARK_MASTER_IP" = "" ]; then
  SPARK_MASTER_IP="0.0.0.0"
fi
if [ "$SPARK_MASTER_WEBUI_PORT" = "" ]; then
  SPARK_MASTER_WEBUI_PORT=8080
fi
if [ "$SPARK_WORKER_WEBUI_PORT" = "" ]; then
  SPARK_WORKER_WEBUI_PORT=8081
fi
if [ "$SPARK_UI_PORT" = "" ]; then
  SPARK_UI_PORT=4040
fi
if [ "$SPARK_WORKER_PORT" = "" ]; then
  SPARK_WORKER_PORT=8581
fi
if [ "$CORES" = "" ]; then
  CORES=1
fi
if [ "$MEM" = "" ]; then
  MEM=1g
fi
if [ "$SPARK_MASTER_HOSTNAME" = "" ]; then
  SPARK_MASTER_HOSTNAME=`hostname -f`
fi
if [ "$SPARK_CONTAINER_DIR" != "" ]; then
    cp $SPARK_CONTAINER_DIR/datalake-1.1-SNAPSHOT.jar /opt/spark-1.6.2-bin-hadoop2.6/lib
    cp /root/google-collections-1.0.jar /opt/spark-1.6.2-bin-hadoop2.6/lib
fi 

sed "s/HOSTNAME_MASTER/$SPARK_MASTER_HOSTNAME/" /opt/spark-1.6.2-bin-hadoop2.6/conf/spark-defaults.conf.template >> /opt/spark-1.6.2-bin-hadoop2.6/conf/spark-defaults.conf.tmp && \
mv /opt/spark-1.6.2-bin-hadoop2.6/conf/spark-defaults.conf.tmp /opt/spark-1.6.2-bin-hadoop2.6/conf/spark-defaults.conf

sed "s/SPARK_UI_PORT/$SPARK_UI_PORT/" /opt/spark-1.6.2-bin-hadoop2.6/conf/spark-defaults.conf >> /opt/spark-1.6.2-bin-hadoop2.6/conf/spark-defaults.conf.tmp && \
mv /opt/spark-1.6.2-bin-hadoop2.6/conf/spark-defaults.conf.tmp /opt/spark-1.6.2-bin-hadoop2.6/conf/spark-defaults.conf

SPARK_MASTER_URL="spark://$SPARK_MASTER_HOSTNAME:$SPARK_MASTER_PORT"
echo "Using SPARK_MASTER_URL=$SPARK_MASTER_URL"

if [ "$MODE" = "" ]; then
MODE=$1
fi

if [ "$MODE" == "master" ]; then 
	${SPARK_HOME}/bin/spark-class "org.apache.spark.deploy.master.Master" --ip $SPARK_MASTER_IP --port $SPARK_MASTER_PORT --webui-port $SPARK_MASTER_WEBUI_PORT -classpath /opt/spark-1.6.2-bin-hadoop2.6/lib &
	jupyter notebook --ip=0.0.0.0 

elif [ "$MODE" == "worker" ]; then
	${SPARK_HOME}/bin/spark-class "org.apache.spark.deploy.worker.Worker" --webui-port $SPARK_WORKER_WEBUI_PORT --port $SPARK_WORKER_PORT $SPARK_MASTER_URL -c $CORES -m $MEM -classpath /opt/spark-1.6.2-bin-hadoop2.6/lib
else
	${SPARK_HOME}/bin/spark-class "org.apache.spark.deploy.master.Master" --ip $SPARK_MASTER_IP --port $SPARK_MASTER_PORT --webui-port $SPARK_MASTER_WEBUI_PORT -classpath /opt/spark-1.6.2-bin-hadoop2.6/lib &
	${SPARK_HOME}/bin/spark-class "org.apache.spark.deploy.worker.Worker" --webui-port $SPARK_WORKER_WEBUI_PORT --port $SPARK_WORKER_PORT $SPARK_MASTER_URL	-c $CORES -m $MEM -classpath /opt/spark-1.6.2-bin-hadoop2.6/lib &
	jupyter notebook --ip=0.0.0.0 
fi
