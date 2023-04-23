DOCKER_NETWORK = docker-hadoop_default
ENV_FILE = hadoop.env
HADOOP_CLASSPATH := $(shell hadoop classpath)
current_dir := $(shell pwd)
current_branch := $(shell git rev-parse --abbrev-ref HEAD)
build:
	docker build -t bde2020/hadoop-base:$(current_branch) ./base
	docker build -t bde2020/hadoop-namenode:$(current_branch) ./namenode
	docker build -t bde2020/hadoop-datanode:$(current_branch) ./datanode
	docker build -t bde2020/hadoop-resourcemanager:$(current_branch) ./resourcemanager
	docker build -t bde2020/hadoop-nodemanager:$(current_branch) ./nodemanager
	docker build -t bde2020/hadoop-historyserver:$(current_branch) ./historyserver
	docker build -t bde2020/hadoop-submit:$(current_branch) ./submit

wordcount:
	docker build -t hadoop-wordcount ./submit
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -mkdir -p /input/
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -copyFromLocal -f /opt/hadoop-3.2.1/README.txt /input/
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} hadoop-wordcount
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -cat /output/*
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -rm -r /output
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -rm -r /input

get_namenode:
	docker exec -it namenode hdfs getconf -namenodes

launch_cluster:
	docker-compose -f docker-compose-3dn.yml up -d

stop_cluster:
	docker-compose -f docker-compose-3dn.yml down

compile_word_count:
	javac -classpath $(HADOOP_CLASSPATH) -d $(current_dir)/programs/wordCount/classes $(current_dir)/programs/wordCount/WordCount.java
	jar -cvf ${current_dir}/programs/wordCount/word_count.jar -C ${current_dir}/programs/wordCount/classes .

run_word_count:
	docker cp ${current_dir}/programs/wordCount/word_count.jar namenode:/tmp/
	docker cp ${current_dir}/programs/wordCount/poem.txt namenode:/tmp/
	docker exec -it namenode hdfs dfs -mkdir -p /user/root
	docker exec -it namenode hdfs dfs -mkdir /user/root/input
	docker exec -it namenode hdfs dfs -put /tmp/poem.txt /user/root/input
	docker exec -it namenode hadoop jar /tmp/word_count.jar WordCount input output
