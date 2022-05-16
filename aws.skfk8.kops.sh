##!/bin/bash

export KOPS_HOSTNAME="fwdsec.xyz"
export KOPS_HOSTZONEID="Z03168273ESGGCHLPJSWY"
export CERT_EMAIL='info@owasptalk.fwdsec.xyz'
export KOPS_LABSHOSTNAME="skflabs.owasptalk.$KOPS_HOSTNAME"
export KOPS_DEMOHOSTNAME="skfdemo.owasptalk.$KOPS_HOSTNAME"

export KOPS_KEY=kops_rsa
export KOPS_PUBKEY=kops_rsa.pub 

export KOPS_BUCKET=k8skf-fwdsec-xyz

export kops_statestore=$KOPS_BUCKET-state-store
export kops_oidcstore=$KOPS_BUCKET-oidc-store

export KOPS_SKFLABS=k8skf-labs.$KOPS_HOSTNAME
export KOPS_STATE_SKFLABS=s3://$kops_statestore
export KOPS_DISCOVERY_SKFLABS=s3://$kops_oidcstore/${KOPS_SKFLABS}/discovery

export KOPS_SKFDEMO=k8skf-demo.$KOPS_HOSTNAME
export KOPS_STATE_SKFDEMO=s3://$kops_statestore
export KOPS_DISCOVERY_SKFDEMO=s3://$kops_oidcstore/${KOPS_SKFDEMO}/discovery

## These variables are captured after brigning up the ALBs instances.
## '220-apply-cnames' uses the values set in '050-get-ingress-skflabs' and '150-get-ingress-skfdemo'
export LB_LABSHOSTNAME=
export LB_DEMOHOSTNAME=

000-welcome-k8skf() {
    ##region FWDSEC:K8SKF         
    cat << EOF
Forward Security:
 _    _____     _     __ 
| |  |  _  |   | |   / _|
| | __\ V / ___| | _| |_ 
| |/ // _ \/ __| |/ /  _|
|   <| |_| \__ \   <| |  
|_|\_\_____/___/_|\_\_|  

k8skf/kops.sh build out script v1.0 :-)
EOF
    ##endregion method1

    echo "[CHECK] Checking for prereqs to install SKF into Kubernetes on AWS ...."
    depsfail=0
    for name in kops helm aws kubectl terraform jq sleep certbot
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
        aws sts get-caller-identity

        echo "\n[SUCCESS] Next try running '001-init-aws-kops', '002-init-aws-kops-s3' and '003-init-lets-encrypt' "
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

    CredentialsJson=$(aws iam create-access-key --user-name root.kops | tee kops.creds.txt)
    export AWS_ACCESS_KEY_ID=$(echo $CredentialsJson | jq -r .AccessKey.AccessKeyId)
    export AWS_SECRET_ACCESS_KEY=$(echo $CredentialsJson | jq -r .AccessKey.SecretAccessKey)
    
    ## This public key will be copied over, and can be used to ssh into the instance
    ssh-keygen -f $KOPS_KEY
    
    echo "Sleeping for 15 seconds to let AWS catch-up with IAM provisioning ..."
    sleep 15

    aws sts get-caller-identity
}
002-init-aws-kops-s3() {
    ##On MacOS the this may be set to 'less' which pauses the output.
    unset PAGER

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
003-init-lets-encrypt() {
    ## Let's Encrypt get the certificate using DNS validation
    ##Manual and interactive with pausing for DNS record updates.
    certbot --config-dir=./letsencrypt/ \
        --manual \
        --email $CERT_EMAIL \
        --agree-tos \
        --preferred-challenges dns certonly \
        --work-dir=./letsencrypt/ \
        --logs-dir=./letsencrypt/log/ \
        -d ${KOPS_DEMOHOSTNAME} -d ${KOPS_LABSHOSTNAME} -d \*.${KOPS_LABSHOSTNAME}
}
#   _  _____   _____ _  ________ _               ____   _____ 
#  | |/ / _ \ / ____| |/ /  ____| |        /\   |  _ \ / ____|
#  | ' / (_) | (___ | ' /| |__  | |       /  \  | |_) | (___  
#  |  < > _ < \___ \|  < |  __| | |      / /\ \ |  _ < \___ \ 
#  | . \ (_) |____) | . \| |    | |____ / ____ \| |_) |____) |
#  |_|\_\___/|_____/|_|\_\_|    |______/_/    \_\____/|_____/ 

010-define-k8skf-labs() {
    ##Interactive can version etc.
    kops create cluster \
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
        ${KOPS_SKFLABS}

    ## Set kubernetes version proper: kubernetesVersion: 1.18.20
    kops edit cluster --name ${KOPS_SKFLABS} --state=${KOPS_STATE_SKFLABS}

    ## You can use spot instanace instead with something like this:
    #   machineType: t2.large
    #   maxPrice: "0.030"
    #   maxSize: 3
    #   minSize: 1
    kops edit ig --name ${KOPS_SKFLABS} --state=${KOPS_STATE_SKFLABS} master-us-east-1a
    kops edit ig --name ${KOPS_SKFLABS} --state=${KOPS_STATE_SKFLABS} nodes-us-east-1a
}
020-create-k8skf-labs() {
    kops update cluster --name ${KOPS_SKFLABS} --state=${KOPS_STATE_SKFLABS} --yes --admin
}
030-validate-k8skf-labs() {
    kops validate cluster --name ${KOPS_SKFLABS} --state=${KOPS_STATE_SKFLABS} --wait 45m
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

    ##Capture the Kubeconfig for the `configmaps.yaml` SKF requirement.
    cat ~/.kube/config|base64 > skflabs.kubeconfig.b64
}
050-get-ingress-skflabs() {
    OUTPUT=$(kubectl --namespace default --kubeconfig <(base64 -d skflabs.kubeconfig.b64) get services -o wide ingress-nginx-controller)
    export LB_LABSHOSTNAME=$(echo $OUTPUT |head -n2|tail -n1|tr -s ' '|cut -f4 -d' ')
    echo Put \"$LB_LABSHOSTNAME\" into a Route53 CNAME record for the $KOPS_LABSHOSTNAME
}

#   _  _____   _____ _  ________ _____  ______ __  __  ____  
#  | |/ / _ \ / ____| |/ /  ____|  __ \|  ____|  \/  |/ __ \ 
#  | ' / (_) | (___ | ' /| |__  | |  | | |__  | \  / | |  | |
#  |  < > _ < \___ \|  < |  __| | |  | |  __| | |\/| | |  | |
#  | . \ (_) |____) | . \| |    | |__| | |____| |  | | |__| |
#  |_|\_\___/|_____/|_|\_\_|    |_____/|______|_|  |_|\____/ 

110-define-k8skf-demo() {
    ##Configure the cluster - run this many times to get configuration right now harm.
    kops create cluster \
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
        ${KOPS_SKFDEMO}

    ## Set kubernetes version proper: kubernetesVersion: 1.18.20
    kops edit cluster --name ${KOPS_SKFDEMO} --state=${KOPS_STATE_SKFDEMO}

    ## You can use spot instanace instead with something like this:
    #   machineType: t2.large
    #   maxPrice: "0.030"
    #   maxSize: 3
    #   minSize: 1
    kops edit ig --name ${KOPS_SKFDEMO} --state=${KOPS_STATE_SKFDEMO} master-us-east-1a
    kops edit ig --name ${KOPS_SKFDEMO} --state=${KOPS_STATE_SKFDEMO} nodes-us-east-1a
}
120-create-k8skf-demo() {
    kops update cluster --name ${KOPS_SKFDEMO} --state=${KOPS_STATE_SKFDEMO} --yes --admin
}
130-validate-k8skf-demo() {
    kops validate cluster --name ${KOPS_SKFDEMO} --state=${KOPS_STATE_SKFDEMO} --wait 45m
}
140-create-ingress-skfdemo() {
    #Current SKF head is using Kubernetes 1.18.20, which is an older ingress definition
    helm install ingress-nginx ingress-nginx --version 3.40.0 \
        --repo https://kubernetes.github.io/ingress-nginx \
        --set rbac.create=true \
        --set controller.publishService.enabled=true \
        --set controller.service.externalTrafficPolicy=Local \
        --set controller.setAsDefaultIngress=true

    cat ~/.kube/config|base64 > skfdemo.kubeconfig.b64
}
150-get-ingress-skfdemo() {
    OUTPUT=$(kubectl --namespace default --kubeconfig <(base64 -d skfdemo.kubeconfig.b64) get services -o wide ingress-nginx-controller)
    export LB_DEMOHOSTNAME=$(echo $OUTPUT |head -n2|tail -n1|tr -s ' '|cut -f4 -d' ')
    echo Put \"$LB_DEMOHOSTNAME\" into a Route53 CNAME record for the $KOPS_DEMOHOSTNAME
}

#    _____ _  ________ _____  ______ _____  _      ______     __
#   / ____| |/ /  ____|  __ \|  ____|  __ \| |    / __ \ \   / /
#  | (___ | ' /| |__  | |  | | |__  | |__) | |   | |  | \ \_/ / 
#   \___ \|  < |  __| | |  | |  __| |  ___/| |   | |  | |\   /  
#   ____) | . \| |    | |__| | |____| |    | |___| |__| | | |   
#  |_____/|_|\_\_|    |_____/|______|_|    |______\____/  |_|   

200-substr-skfconfig() {
    sed -i "" -E "s#([ \t]*LABS_KUBE_CONF):.*#\1: \"`cat skflabs.kubeconfig.b64`\"#" skf/configmaps.yaml
    sed -i "" -E "s#([ \t]*SKF_LABS_DOMAIN):.*#\1: \"http://${KOPS_LABSHOSTNAME}\"#" skf/configmaps.yaml
    sed -i "" -E "s#([ \t]*SKF_API_URL):.*#\1: \"http://${KOPS_DEMOHOSTNAME}/api\"#" skf/configmaps.yaml
    sed -i "" -E "s#([ \t]*FRONTEND_URI):.*#\1: \"https://${KOPS_DEMOHOSTNAME}\"#" skf/configmaps.yaml
}

210-apply-skf() {
    kubectl apply -f skf/configmaps.yaml
    for yaml in skf/Deployment*.yaml; do
        kubectl apply -f $yaml;
    done

    ## This is the last version that supports this ingress definition
    kubectl apply -f skf/ingress.1.18.yaml

    ## Load the secret necessary for the TLS
    kubectl create secret tls ${KOPS_DEMOHOSTNAME} --key ./letsencrypt/live/${KOPS_DEMOHOSTNAME}/privkey.pem --cert ./letsencrypt/live/${KOPS_DEMOHOSTNAME}/fullchain.pem
}

220-apply-cnames() {
    export PAGER=""

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
}

888-MacOS-clear-cache() {
    ##Clearing the cache fixes the slow-to-come-up... 
    sudo dscacheutil -flushcache;sudo killall -HUP mDNSResponder
}

999-destroy-clusters() {
    kops delete cluster --name ${KOPS_SKFDEMO} --state=${KOPS_STATE_SKFDEMO} --yes
    kops delete cluster --name ${KOPS_SKFLABS} --state=${KOPS_STATE_SKFLABS} --yes
}

