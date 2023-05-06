DOCKER_NETWORK = search_engine_default
ENV_FILE = hadoop.env
current_dir := $(shell pwd)
current_branch = 2.0.0-hadoop3.2.1-java8
build:
	docker build -t bde2020/hadoop-base:$(current_branch) ./base
	docker build -t bde2020/hadoop-namenode:$(current_branch) ./namenode
	docker build -t bde2020/hadoop-datanode:$(current_branch) ./datanode
	docker build -t bde2020/hadoop-resourcemanager:$(current_branch) ./resourcemanager
	docker build -t bde2020/hadoop-nodemanager:$(current_branch) ./nodemanager
	docker build -t bde2020/hadoop-historyserver:$(current_branch) ./historyserver
	docker build -t bde2020/hadoop-submit:$(current_branch) ./submit

launch_cluster:
	docker-compose -f docker-compose-3dn.yml up -d

stop_cluster:
	docker-compose -f docker-compose-3dn.yml down

delete-files:
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -rm -r /input
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -rm -r /output
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -rm -r /output_pagerank

delete-pr:
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -rm -r /output_pagerank

wordcount:
	docker build -t hadoop-wordcount ./submit
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -mkdir -p /input/
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -copyFromLocal -f /opt/hadoop-3.2.1/README.txt /input/
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} hadoop-wordcount
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -cat /output/*

invertedindex:
	docker build -t hadoop-invertedindex ./inverted_index
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} hadoop-invertedindex hdfs dfs -mkdir -p /input/
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} hadoop-invertedindex hdfs dfs -copyFromLocal -f /opt/input/* /input/
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} hadoop-invertedindex
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -cat /output/*

pagerank:
	docker build --file ./page_rank/Dockerfile-pr-initializer -t hadoop-pagerank ./page_rank
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -cat /output/*
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} hadoop-pagerank
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -cat /output_pagerank/*

pagerank-complete:
	docker build --file ./page_rank/Dockerfile-outlinks -t hadoop-outlinks ./page_rank
	docker build --file ./page_rank/Dockerfile-pr-initializer -t hadoop-pagerank ./page_rank
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} hadoop-outlinks hdfs dfs -mkdir -p /input/
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} hadoop-outlinks hdfs dfs -copyFromLocal -f /opt/input/* /input/
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} hadoop-outlinks
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -cat /output/pagerank/*
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} hadoop-pagerank
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -cat /output_pagerank/*

print-output:
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -cat /output/*
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(current_branch) hdfs dfs -cat /output_pagerank/*

run_word_count_python:
# docker exec -it namenode bash -c "apt-get install wget && wget https://www.python.org/ftp/python/3.7.15/Python-3.7.15.tgz"
# docker exec -it datanode1 bash -c "apt-get update && apt-get install python3 -y"
# docker exec -it datanode2 bash -c "apt-get update && apt-get install python3 -y"
# docker exec -it datanode3 bash -c "apt-get update && apt-get install python3 -y"
# docker exec -it resourcemanager bash -c "apt update && apt install python3 -y"
# docker exec -it nodemanager1 bash -c "apt update && apt install python3 -y"
	docker cp ${current_dir}/programs/wordCountPython/mapper.py namenode:mapper.py
	docker cp ${current_dir}/programs/wordCountPython/reducer.py namenode:reducer.py
	docker cp ${current_dir}/programs/wordCountPython/poem.txt namenode:poem.txt
#	docker cp ${current_dir}/streamer/hadoop-streaming-3.1.2.jar namenode:/tmp/
	docker exec -it namenode chmod 777 mapper.py reducer.py
	docker exec -it namenode hdfs dfs -rm -r -f /user/root/word_count_python
	docker exec -it namenode hdfs dfs -mkdir -p /user/root/word_count_python
	docker exec -it namenode hdfs dfs -put poem.txt /user/root/word_count_python
	docker exec -it namenode hadoop jar /opt/hadoop-3.2.1/share/hadoop/tools/lib/hadoop-streaming-3.2.1.jar \
	-input /user/root/word_count_python \
	-output /user/root/word_count_python/output \
	-file mapper.py -mapper mapper.py \
	-file reducer.py -reducer reducer.py
	