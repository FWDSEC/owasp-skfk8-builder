#!/bin/bash

brew install minikube
brew install awscli
brew install jq
brew install hyperkit

minikube start --kubernetes-version=1.18.20 --vm-driver=hyperkit --embed-certs=true

git clone https://github.com/blabla1337/skf-flask --depth=1 && \
    cd skf-flask/ && \
    echo itsdangerous==2.0.1 >> requirements.txt && \
    pip install -r requirements.txt


minikube start --kubernetes-version=1.18.20 --vm-driver=hyperkit --embed-certs=true
chmod 666 ~/.kube/config ##This is so the Docker container user can read it, which is uid:1000|gid:1000

sed -i "" -E "s#~/.kube/config:/home/user_api/.kube/config#${HOME}/.kube/config:/home/user_api/.kube/config#" docker-compose.yml
sed -i "" -E "s/YXBpVmVyc2lvbjogdjEKY2x1c3RlcnM6Ci0gY2x1c3RlcjoKICAgIGNlcnRpZmljY_update_me.../`cat ${HOME}/.kube/config | base64 | tr -d '\n'`/g" docker-compose.yml
sed -i "" -E "s#FRONTEND_URI=http://localhost#FRONTEND_URI=http://localhost#" docker-compose.yml
sed -i "" -E "s#SKF_API_URL=http://localhost/api#SKF_API_URL=http://127.0.0.1/api#" docker-compose.yml
sed -i "" -E "s#SKF_LABS_DOMAIN=http://localhost#SKF_LABS_DOMAIN=http://$()#" docker-compose.yml

sh -c "docker-compose up -d"
