#!/bin/bash

#export KOPS_BIN="./bin/kops.v1.22.darwin.amd64" //##OSX setting
#export KOPS_BIN="./bin/kops.v1.22.linux.amd64"
export KOPS_BIN="/usr/local/bin/kops"

##export SED ='sed -i "" -E' //##OSX setting!!
export SED='sed -i -E'

#export K8_VERSION="v1.18.20"
export K8_VERSION="v1.21.14"

export KOPS_HOSTNAME="fwdsec.xyz"
export KOPS_HOSTZONEID="Z03168273ESGGCHLPJSWY"
export CERT_EMAIL='k.hundeck@fwdsec.com'
export KOPS_LABSHOSTNAME="sector-skflabs.$KOPS_HOSTNAME"
export KOPS_DEMOHOSTNAME="sector-skfdemo.$KOPS_HOSTNAME"

export KOPS_KEY=kops_rsa
export KOPS_PUBKEY=kops_rsa.pub 

export KOPS_BUCKET=k8skf-fwdsec-xyz

export kops_statestore=$KOPS_BUCKET-state-store
export kops_oidcstore=$KOPS_BUCKET-oidc-store

export KOPS_SKFLABS=${KOPS_LABSHOSTNAME}
export KOPS_STATE_SKFLABS=s3://$kops_statestore
export KOPS_DISCOVERY_SKFLABS=s3://$kops_oidcstore/${KOPS_SKFLABS}/discovery

export KOPS_SKFDEMO=${KOPS_DEMOHOSTNAME}
export KOPS_STATE_SKFDEMO=s3://$kops_statestore
export KOPS_DISCOVERY_SKFDEMO=s3://$kops_oidcstore/${KOPS_SKFDEMO}/discovery

## These variables are captured after brigning up the ALBs instances.
## '220-apply-cnames' uses the values set in '050-get-ingress-skflabs' and '150-get-ingress-skfdemo'
export LB_LABSHOSTNAME=
export LB_DEMOHOSTNAME=

000-welcome-k8skf() {
    ##region FWDSEC:K8SKF         
    cat << EOF
Forward Security 2022 Relase:
 _    _____     _     __ 
| |  |  _  |   | |   / _|
| | __\ V / ___| | _| |_ 
| |/ // _ \/ __| |/ /  _|
|   <| |_| \__ \   <| |  
|_|\_\_____/___/_|\_\_|  

Kubernetes 1.18.20 build out for OWASP SKF

k8skf/kops.sh build out script v1.0 :-)
EOF
    ##endregion

    echo "[CHECK] Checking for prereqs to install SKF into Kubernetes on AWS ...."
    depsfail=0
    for name in ./bin/kops.v1.22.* helm aws kubectl terraform jq sleep certbot
    do
        if command -v $name >/dev/null 2>&1 ; then
            echo "[SUCCESS] '$name' is installed.."
        else 
            echo "[ERROR] '$name' was not found and is required."
            depsfail=121
        fi
    done

    if [[ $depsfail -eq 121 ]] ; then
        echo -en "[FAILED] Please install the above tools for successful execution.\n" 
    else
        echo "\n[SUCCESS] Looks like you have all of the tools needed! :-)\n"
        echo "[SUCCESS] AWS IAM user in the profile '${AWS_PROFILE:-"default"}' will need the necessary permissions to create a user/group in '001-init-aws-kops'"
        echo "Output:"
        export PAGER=
        aws sts get-caller-identity

        echo "\n[SUCCESS] Next try running '001-init-aws-kops', '002-switch-to-iam-kopsroot', '003-init-aws-kops-s3' and '004-init-lets-encrypt' "
    fi 

}
000-welcome-k8skf

001-init-aws-kops() { 
    ## Create the root.kops user and group, outputting the credentials
    ## to the 'kops.creds.txt'

    export PAGER=

    ## Create a group to attach policies to
    aws iam create-group --group-name root.kops

    ## Attach the policies necessary to deploy Kubernetes using KOPS.
    aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess --group-name root.kops
    aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess --group-name root.kops
    aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --group-name root.kops
    aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/IAMFullAccess --group-name root.kops
    aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess --group-name root.kops
    aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonSQSFullAccess --group-name root.kops
    aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonEventBridgeFullAccess --group-name root.kops

    ## Create the user 'root.kops' 
    aws iam create-user --user-name root.kops
    aws iam add-user-to-group --user-name root.kops --group-name root.kops

    aws iam create-access-key --user-name root.kops > kops.creds.json  
    
    ## This public key will be copied over, and can be used to ssh into the instance
    ssh-keygen -t rsa -q -N '' -f $KOPS_KEY
    
    echo "Sleeping for 10 seconds to let AWS catch-up with IAM provisioning ..."
    sleep 10
}
002-switch-to-iam-kopsroot() {
    export AWS_ACCESS_KEY_ID=$(cat kops.creds.json | jq -r .AccessKey.AccessKeyId)
    export AWS_SECRET_ACCESS_KEY=$(cat kops.creds.json | jq -r .AccessKey.SecretAccessKey)
    aws sts get-caller-identity
}
003-init-aws-kops-s3() {
    ##On MacOS the this may be set to 'less' which pauses the output.
    export PAGER=

    ## These buckets hold the kops buildstates, versioned and encrypted
    aws s3api create-bucket \
        --bucket $kops_statestore \
        --region us-east-1 ## Has to be in this region, doen't work with ca-central-1

    aws s3api put-bucket-versioning \
        --bucket $kops_statestore \
        --versioning-configuration Status=Enabled

    aws s3api put-bucket-encryption \
        --bucket $kops_statestore \
        --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

    # OIDC used for demo->labs communcation and OAuth OpenID document
    aws s3api create-bucket \
        --bucket $kops_oidcstore \
        --acl public-read \
        --region us-east-1 ## Has to be in this region, doen't work with ca-central-1

}
004-init-lets-encrypt() {
    ## Let's Encrypt get the certificate using DNS validation
    ##Manual and interactive with pausing for DNS record updates.
    certbot --config-dir=./letsencrypt/ \
        --dns-route53 \
        --email $CERT_EMAIL \
        --agree-tos \
        --non-interactive \
        --preferred-challenges dns certonly \
        --work-dir=./letsencrypt/ \
        --logs-dir=./letsencrypt/log/ \
        -d ${KOPS_DEMOHOSTNAME} -d ${KOPS_LABSHOSTNAME} -d \*.${KOPS_LABSHOSTNAME}
}

##################################################
#   _  _____   _____ _  ________ _               ____   _____ 
#  | |/ / _ \ / ____| |/ /  ____| |        /\   |  _ \ / ____|
#  | ' / (_) | (___ | ' /| |__  | |       /  \  | |_) | (___  
#  |  < > _ < \___ \|  < |  __| | |      / /\ \ |  _ < \___ \ 
#  | . \ (_) |____) | . \| |    | |____ / ____ \| |_) |____) |
#  |_|\_\___/|_____/|_|\_\_|    |______/_/    \_\____/|_____/ 
##################################################

010-define-k8skf-labs() {
    ##Interactive can version etc.
    ${KOPS_BIN} create cluster \
        --kubernetes-version ${K8_VERSION} \
        --cloud aws \
        --networking amazonvpc \
        --api-loadbalancer-class network \
        --api-loadbalancer-type public \
        --discovery-store=${KOPS_DISCOVERY_SKFLABS} \
        --state=${KOPS_STATE_SKFLABS} \
        --ssh-public-key=${KOPS_PUBKEY} \
        --master-size t2.large \
        --node-size t2.large \
        --zones us-east-1a \
        --master-zones us-east-1a \
        --name ${KOPS_SKFLABS}

    ## Example to manually edit k8 cluster definition before building:
    #${KOPS_BIN} edit cluster --name ${KOPS_SKFLABS} --state=${KOPS_STATE_SKFLABS}


    ## Example to use spot instances for cheaper playtime:
    ## You can use spot instanace instead with something like this:
    #   machineType: t2.large
    #   maxPrice: "0.030"
    #   maxSize: 3
    #   minSize: 1
    #${KOPS_BIN} edit ig --name ${KOPS_SKFLABS} --state=${KOPS_STATE_SKFLABS} master-us-east-1a
    #${KOPS_BIN} edit ig --name ${KOPS_SKFLABS} --state=${KOPS_STATE_SKFLABS} nodes-us-east-1a
}
020-create-k8skf-labs() {
    ${KOPS_BIN} update cluster --name ${KOPS_SKFLABS} --state=${KOPS_STATE_SKFLABS} --yes --admin --create-kube-config=false
}
030-validate-k8skf-labs() {
    ${KOPS_BIN} validate cluster --name ${KOPS_SKFLABS} --state=${KOPS_STATE_SKFLABS} --wait 45m
}
040-create-ingress-skflabs() {
    #Current SKF head is using Kubernetes 1.18.20, which is an older ingress definition

    ##Install ingres! - RUN ONCE!
    helm install ingress-nginx ingress-nginx --version 3.40.0 \
        --repo https://kubernetes.github.io/ingress-nginx \
        --set rbac.create=true \
        --set controller.publishService.enabled=true \
        --set controller.service.externalTrafficPolicy=Local \
        --set controller.setAsDefaultIngress=true 

    ${KOPS_BIN} export kubeconfig --name ${KOPS_SKFLABS} --state=${KOPS_STATE_SKFLABS} --admin

    ##Capture the Kubeconfig for the `configmaps.yaml` SKF requirement.
    cat skflabs.kubeconfig |base64 > skflabs.kubeconfig.b64
    rm skflabs.kubeconfig
}
050-get-ingress-skflabs() {
    OUTPUT=$(kubectl --namespace default --kubeconfig <(base64 -d skflabs.kubeconfig.b64) get services -o wide ingress-nginx-controller)
    export LB_LABSHOSTNAME=$(echo $OUTPUT |head -n2|tail -n1|tr -s ' '|cut -f11 -d' ')
    echo Put \"$LB_LABSHOSTNAME\" into a Route53 CNAME record for the $KOPS_LABSHOSTNAME
}

##################################################
#   _  _____   _____ _  ________ _____  ______ __  __  ____  
#  | |/ / _ \ / ____| |/ /  ____|  __ \|  ____|  \/  |/ __ \ 
#  | ' / (_) | (___ | ' /| |__  | |  | | |__  | \  / | |  | |
#  |  < > _ < \___ \|  < |  __| | |  | |  __| | |\/| | |  | |
#  | . \ (_) |____) | . \| |    | |__| | |____| |  | | |__| |
#  |_|\_\___/|_____/|_|\_\_|    |_____/|______|_|  |_|\____/ 
##################################################
110-define-k8skf-demo() {
    ##Configure the cluster - run this many times to get configuration right now harm.
    ${KOPS_BIN} create cluster \
        --kubernetes-version ${K8_VERSION} \
        --cloud aws \
        --networking amazonvpc \
        --api-loadbalancer-class network \
        --api-loadbalancer-type public \
        --discovery-store=${KOPS_DISCOVERY_SKFDEMO} \
        --state=${KOPS_STATE_SKFDEMO} \
        --ssh-public-key=${KOPS_PUBKEY} \
        --master-size t2.large \
        --node-size t2.large \
        --zones us-east-1a \
        --master-zones us-east-1a \
        --name ${KOPS_SKFDEMO}

    # --node-count 3 

    ## Set kubernetes version proper: kubernetesVersion: 1.18.20
    #${KOPS_BIN} edit cluster --name ${KOPS_SKFDEMO} --state=${KOPS_STATE_SKFDEMO}

    ## You can use spot instanace instead with something like this:
    #   machineType: t2.large
    #   maxPrice: "0.030"
    #   maxSize: 3
    #   minSize: 1
    #${KOPS_BIN} edit ig --name ${KOPS_SKFDEMO} --state=${KOPS_STATE_SKFDEMO} master-us-east-1a
    #${KOPS_BIN} edit ig --name ${KOPS_SKFDEMO} --state=${KOPS_STATE_SKFDEMO} nodes-us-east-1a
}
120-create-k8skf-demo() {
    ${KOPS_BIN} update cluster --name ${KOPS_SKFDEMO} --state=${KOPS_STATE_SKFDEMO} --yes --admin 
}
130-validate-k8skf-demo() {
    ${KOPS_BIN} validate cluster --name ${KOPS_SKFDEMO} --state=${KOPS_STATE_SKFDEMO} --wait 45m
}
140-create-ingress-skfdemo() {
    #Current SKF head is using Kubernetes 1.18.20, which is an older ingress definition
    helm install ingress-nginx ingress-nginx --version 3.40.0 \
        --repo https://kubernetes.github.io/ingress-nginx \
        --set rbac.create=true \
        --set controller.publishService.enabled=true \
        --set controller.service.externalTrafficPolicy=Local \
        --set controller.setAsDefaultIngress=true

    ${KOPS_BIN} export kubeconfig --name ${KOPS_SKFDEMO} --state=${KOPS_STATE_SKFDEMO} --admin --kubeconfig skfdemo.kubeconfig

    ##Capture the Kubeconfig for the `configmaps.yaml` SKF requirement.
    cat skfdemo.kubeconfig |base64 > skfdemo.kubeconfig.b64
    rm skfdemo.kubeconfig
}

150-get-ingress-skfdemo() {
    OUTPUT=$(kubectl --namespace default --kubeconfig <(base64 -d skfdemo.kubeconfig.b64) get services -o wide ingress-nginx-controller)
    export LB_DEMOHOSTNAME=$(echo $OUTPUT |head -n2|tail -n1|tr -s ' '|cut -f11 -d' ')
    echo Put \"$LB_DEMOHOSTNAME\" into a Route53 CNAME record for the $KOPS_DEMOHOSTNAME
}

#    _____ _  ________ _____  ______ _____  _      ______     __
#   / ____| |/ /  ____|  __ \|  ____|  __ \| |    / __ \ \   / /
#  | (___ | ' /| |__  | |  | | |__  | |__) | |   | |  | \ \_/ / 
#   \___ \|  < |  __| | |  | |  __| |  ___/| |   | |  | |\   /  
#   ____) | . \| |    | |__| | |____| |    | |___| |__| | | |   
#  |_____/|_|\_\_|    |_____/|______|_|    |______\____/  |_|   

200-substr-skfconfig() {
    $SED 's/([ \t]*LABS_KUBE_CONF):.*/\1: "'$(cat skflabs.kubeconfig.b64 | tr -d '\n')'"/' skfk8/configmaps.yaml
    $SED 's#([ \t]*SKF_LABS_DOMAIN):.*#\1: "http://'${KOPS_LABSHOSTNAME}'"#' skfk8/configmaps.yaml
    $SED 's#([ \t]*SKF_API_URL):.*#\1: \"http://'${KOPS_DEMOHOSTNAME}'/api"#' skfk8/configmaps.yaml
    $SED 's#([ \t]*FRONTEND_URI):.*#\1: "https://'${KOPS_DEMOHOSTNAME}'"#' skfk8/configmaps.yaml

    $SED 's#([ \t]*secretName):.*#\1: '${KOPS_DEMOHOSTNAME}'#' skfk8/ingress.1.18.yaml
    $SED 's#([ \t\-]*host):.*#\1: '${KOPS_DEMOHOSTNAME}'#' skfk8/ingress.1.18.yaml
    $SED 's#^([ \t\-]*)([^:]*)\$#\1'${KOPS_DEMOHOSTNAME}'#' skfk8/ingress.1.18.yaml

}

210-apply-skf() {
    kubectl apply -f skfk8/configmaps.yaml
    for yaml in skfk8/Deployment*.yaml; do
        kubectl apply -f $yaml;
    done

    ## This is the last version that supports this ingress definition
    kubectl apply -f skfk8/ingress.1.18.yaml

    ## Load the secret necessary for the TLS
    kubectl create secret tls ${KOPS_DEMOHOSTNAME} --key ./letsencrypt/live/${KOPS_DEMOHOSTNAME}/privkey.pem --cert ./letsencrypt/live/${KOPS_DEMOHOSTNAME}/fullchain.pem
}

220-apply-cnames() {
    export PAGER=""
    ##region DemoHostname Route53 Rules
    aws route53 change-resource-record-sets --hosted-zone-id "/hostedzone/$KOPS_HOSTZONEID" --change-batch file://<(cat << EOF
    {
    "Comment": "Creating CNAME record set",
    "Changes": [
        {
        "Action": "CREATE",
        "ResourceRecordSet": {
            "Name": "$KOPS_DEMOHOSTNAME",
            "Type": "CNAME",
            "TTL": 60,
            "ResourceRecords": [
            {
                "Value": "$LB_DEMOHOSTNAME"
            }
            ]
        }
        }
    ]
    }
EOF
)
    ##endregion 
    ##region LabHostname Route53 Rules
    aws route53 change-resource-record-sets --hosted-zone-id "/hostedzone/$KOPS_HOSTZONEID" --change-batch file://<(cat << EOF
    {
    "Comment": "Creating CNAME record set",
    "Changes": [
        {
        "Action": "CREATE",
        "ResourceRecordSet": {
            "Name": "$KOPS_LABSHOSTNAME",
            "Type": "CNAME",
            "TTL": 60,
            "ResourceRecords": [
            {
                "Value": "$LB_LABSHOSTNAME"
            }
            ]
        }
        }
    ]
    }
EOF
)
    ##endregion    
    ##region *.LabHostname Route53 Rules
    aws route53 change-resource-record-sets --hosted-zone-id "/hostedzone/$KOPS_HOSTZONEID" --change-batch file://<(cat << EOF
    {
    "Comment": "Creating CNAME record set",
    "Changes": [
        {
        "Action": "CREATE",
        "ResourceRecordSet": {
            "Name": "*.$KOPS_LABSHOSTNAME",
            "Type": "CNAME",
            "TTL": 60,
            "ResourceRecords": [
            {
                "Value": "$LB_LABSHOSTNAME"
            }
            ]
        }
        }
    ]
    }
EOF
)
    ##endregion
}

999-destroy-clusters() {
    ${KOPS_BIN} delete cluster --name ${KOPS_SKFLABS} --state=${KOPS_STATE_SKFLABS} --yes
    ${KOPS_BIN} delete cluster --name ${KOPS_SKFDEMO} --state=${KOPS_STATE_SKFDEMO} --yes
}


##Install on Ubuntu
# curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
# sudo apt-get install apt-transport-https --yes
# echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
# sudo apt update -y
# sudo apt install helm -y

##Install kubectl on Ubuntu 
# sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
# echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
# sudo apt update -y
# sudo apt install -y kubectl

##Install terraform on Ubuntu
# sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
# wget -O- https://apt.releases.hashicorp.com/gpg | \
#     gpg --dearmor | \
#     sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
# echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
#     https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
#     sudo tee /etc/apt/sources.list.d/hashicorp.list
# sudo apt update
# sudo apt-get install terraform

## AWS cli, jq, certbot, etc.
##sudo apt install awscli jq certbot python3-certbot-dns-route53 -y

##Latest kops on Ubuntu
#KOPS_VERSON v1.25.0
#curl -Lo kops https://github.com/kubernetes/kops/releases/download/v1.25.0/kops-linux-amd64
#chmod +x kops
#sudo mv kops /usr/local/bin/kops
