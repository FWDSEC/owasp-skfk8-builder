#!/bin/bash

export K8_VERSION="v1.23.1"
export COMPOSE_FILE="skfk8/compose/docker-compose.yml"

##export K8_VERSION="v1.21.14"


##According to docs v1.23 is not supposed to support 'api_version="networking.k8s.io/v1beta1"' but seems to be with minikube (?)
minikube start --kubernetes-version=$K8_VERSION --embed-certs=true --force-systemd=true

##TODO: Try "sed -i -E ..."

##Reads the $COMPOSE_FILE and replaces with values to use minikube
sed -i'' "s#~/.kube/config:/home/user_api/.kube/config#${HOME}/.kube/config:/home/user_api/.kube/config#" $COMPOSE_FILE
sed -i'' "s/YXBpVmVyc2lvbjogdjEKY2x1c3RlcnM6Ci0gY2x1c3RlcjoKICAgIGNlcnRpZmljY_update_me.../`cat ${HOME}/.kube/config | base64 | tr -d '\n'`/g" $COMPOSE_FILE
sed -i'' "s#FRONTEND_URI=http://localhost#FRONTEND_URI=http://localhost#" $COMPOSE_FILE
sed -i'' "s#SKF_API_URL=http://localhost/api#SKF_API_URL=http://127.0.0.1/api#" $COMPOSE_FILE
sed -i'' "s#SKF_LABS_DOMAIN=http://localhost#SKF_LABS_DOMAIN=http://$(minikube ip)#" $COMPOSE_FILE
sed -i'' "s#:4.\d.\d#:4.1.0#" $COMPOSE_FILE
sed -i'' "s#:4.\d.\d#:4.1.0#" $COMPOSE_FILE

docker-compose -f $COMPOSE_FILE up -d
# docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' skf-nginx_container

##Give the bridges time to come alive (usually instantaneous)
sleep 5

##Connect the bridges between minikube and docker
export brmini=`brctl show|egrep -ie '^br.+veth.*'|cut -f 1|head -n1`
export brdocker=`brctl show|egrep -ie '^br.+veth.*'|cut -f 1|tail -n1`

##ACCEPT all traffic between minikube and docker bridge interfaces
sudo iptables -I DOCKER-USER -i $brmini -o $brdocker -j ACCEPT
sudo iptables -I DOCKER-USER -i $brdocker -o $brmini -j ACCEPT

###DESTROY ALL TRACES and invalidate the configuration above.
# minikube delete --all
# docker-compose down --volumes
# sudo rm -fr ~/.kube/ ~/.minikube/