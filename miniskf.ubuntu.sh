#!/bin/bash

##According to docs v1.23 is not supposed to support 'api_version="networking.k8s.io/v1beta1"' but seems to be with minikube (?)
minikube start --kubernetes-version=v1.23.1 --embed-certs=true --force-systemd=true

##Still supports v1beta1 network pragmas
#minikube start --kubernetes-version=v1.22.15 --embed-certs=true --force-systemd=true

##TODO: Try "sed -i -E ..."
sed -i'' "s#~/.kube/config:/home/user_api/.kube/config#${HOME}/.kube/config:/home/user_api/.kube/config#" docker-compose.yml
sed -i'' "s/YXBpVmVyc2lvbjogdjEKY2x1c3RlcnM6Ci0gY2x1c3RlcjoKICAgIGNlcnRpZmljY_update_me.../`cat ${HOME}/.kube/config | base64 | tr -d '\n'`/g" docker-compose.yml
sed -i'' "s#FRONTEND_URI=http://localhost#FRONTEND_URI=http://localhost#" docker-compose.yml
sed -i'' "s#SKF_API_URL=http://localhost/api#SKF_API_URL=http://127.0.0.1/api#" docker-compose.yml
sed -i'' "s#SKF_LABS_DOMAIN=http://localhost#SKF_LABS_DOMAIN=http://$(minikube ip)#" docker-compose.yml
sed -i'' "s#:4.0.4#:4.1.0#" docker-compose.yml
sed -i'' "s#:4.0.2#:4.1.0#" docker-compose.yml

docker-compose up -d

##Connect the bridges between minikube and docker
export br2=`brctl show|egrep -ie '^br.+veth.*'|cut -f 1|head -n1`
export br3=`brctl show|egrep -ie '^br.+veth.*'|cut -f 1|tail -n1`

##Allow traffic between bridges
sudo iptables -I DOCKER-USER -i $br2 -o $br3 -j ACCEPT
sudo iptables -I DOCKER-USER -i $br3 -o $br2 -j ACCEPT

# docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' skf-nginx_container

###DESTROY ALL TRACES and invalidate the configuration above.
# minikube delete --all
# docker-compose down --volumes
# sudo rm -fr ~/.kube/ ~/.minikube/