#!/bin/bash
#            _       _ _          _          
#           (_)     (_) |        | |         
#  _ __ ___  _ _ __  _| | ___   _| |__   ___ 
# | '_ ` _ \| | '_ \| | |/ / | | | '_ \ / _ \
# | | | | | | | | | | |   <| |_| | |_) |  __/
# |_| |_| |_|_|_| |_|_|_|\_\\__,_|_.__/ \___|
#                                                                                      
export K8_VERSION="v1.23.1"
export COMPOSE_TPL="skfk8/minikube/docker-compose.tpl.yml"
export COMPOSE_FILE="skfk8/minikube/docker-compose.yml"

export SED='sed -e' ##//Ubuntu setting for 'sed'

010-start-minikube() {
    ##According to docs v1.23 is not supposed to support 'api_version="networking.k8s.io/v1beta1"' but seems to be with minikube (?)
    #minikube start --kubernetes-version=$K8_VERSION --embed-certs=true --force-systemd=true

    ##Reads the $COMPOSE_TPL and replaces with values to use minikube
    $SED "s#REPLACE_ME:/home/user_api/.kube/config#${HOME}/.kube/config:/home/user_api/.kube/config#" $COMPOSE_TPL > $COMPOSE_FILE
    $SED "s/REPLACE_ME/`cat ${HOME}/.kube/config | base64 | tr -d '\n'`/g" $COMPOSE_TPL > $COMPOSE_FILE
    $SED "s#FRONTEND_URI=REPLACE_ME#FRONTEND_URI=http://localhost#" $COMPOSE_TPL > $COMPOSE_FILE
    $SED "s#SKF_API_URL=REPLACE_ME#SKF_API_URL=http://127.0.0.1/api#" $COMPOSE_TPL > $COMPOSE_FILE
    $SED "s#SKF_LABS_DOMAIN=REPLACE_ME#SKF_LABS_DOMAIN=http://$(minikube ip)#" $COMPOSE_TPL > $COMPOSE_FILE
    $SED "s#:4.X.X#:4.1.0#" $COMPOSE_TPL > $COMPOSE_FILE

    #docker-compose -f $COMPOSE_FILE up -d
}

011-minikube-iptables() {
    ##Connect the bridges between minikube and docker
    export brmini=`brctl show|egrep -ie '^br.+veth.*'|cut -f 1|head -n1`
    export brdocker=`brctl show|egrep -ie '^br.+veth.*'|cut -f 1|tail -n1`

    ##ACCEPT all traffic between minikube and docker bridge interfaces
    sudo iptables -I DOCKER-USER -i $brmini -o $brdocker -j ACCEPT
    sudo iptables -I DOCKER-USER -i $brdocker -o $brmini -j ACCEPT
}

020-destroy-minikube() {
    ###DESTROY ALL TRACES and invalidate the configuration above.
    docker-compose -f $COMPOSE_TPL down --volumes
    minikube delete --all

    ##Clean-up iptables mapping from non-exitent br (de-composed, and minikube --delete)
    sudo iptables -D DOCKER-USER -i $brmini -o $brdocker -j ACCEPT
    sudo iptables -D DOCKER-USER -i $brdocker -o $brmini -j ACCEPT

    #sudo rm -fr ~/.kube/ ~/.minikube/
}