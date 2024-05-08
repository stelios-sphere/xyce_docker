#this file pushes docker image to docker-hub
docker login --username=spheresemi
docker build ./ -t spheresemi/xyce:v1.0
docker push spheresemi/xyce:v1.0
