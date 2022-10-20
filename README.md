# OWASP SKF K8 Builder Tools

## minkube build on Ubuntu
Running SKF locally on an Ubuntu (VM) with minikube is a great way to get exposure to how SKF is interfacing w/ Kubernetes.

The basic steps are:
1) Get a vanilla `Ubuntu` system up and going with the latest `minikube` running
2) Clone the repository
3) From a terminal '`bash`' window '`source miniskf.ubuntu.sh`' to get access to the minikube SKF functions (eg.`010-minikube-start`, `020-minikube-iptables`, `999-minikube-destroy`)
4) Execute '`010-minikube-start`' and '`020-minikube-iptables`' and you will have a working SKF environemtn.
5) When you're done '`999-minikube-destroy`'

## AWS Buildout Example
This is the Github repo for the talk: "Build more secure apps by harnessing the power of OWASP SKF & ASVS on Kubernetes".

![First Step](https://github.com/FWDSEC/owasp-skfk8-builder/blob/main/docs/firststep.gif)

To get started clone this repository, open a terminal window into the cloned folder, edit these values to yours in `aws.skfk8.kops.sh` at the top:
```bash
export KOPS_HOSTNAME="somesite.xyz" ##[AWS ROUTE53 DOMAIN YOU OWN/OPERATE]"
export KOPS_HOSTZONEID="Z03168273ESGGCHLPJSWY" ## [AWS ROUTE53 HOSTID]
export CERT_EMAIL='info@kops.somesite.xyz'
```
**NOTE:** You will need a registered AWS domain name and to get zone ID.

Set your AWS profile `export AWS_PROFILE=XYZ` and run `source awsskf.kops.sh`. The AWS profile will need sufficient permissions so it can create an IAM `kops user` and IAM `kops group` to create/destroy the K8s clusters (labs/demo).

## AWS SKF+K8 Overview
Gettig OWASP Secure Knowledge Framework up-and-running on a live Kubernetes clusters can be really challenging. We created the `aws.skfk8.kops.sh` to contain a series of shell functions that can be executed in order to create the 2x Kubernetes environments necessary to run the OWASP Secure Knowledge Framework in AWS.

Recently, the Kubernetes standard has changed around Network Ingress deployment definitions (no longer beta!) and currently SKF is only working in Kubernetes `v1.21.14` (or earlier), and `v1.21.14` is End-of-Life. Future code changes to SKF are required because the Python code that deploys various SKF Labs uses the K8S Beta API. Using the `skf/ingress.1.22.yaml` one can deploy the demo site however the lab site deployment fails.

# Tools Need to Build (Linux/MacOS/...)
This script uses the latest [kops](https://kops.sigs.k8s.io/) under the hood and requires these other packages:
1. kops
2. terraform
3. AWS cli
4. kubectl
5. helm
6. jq

# Convert MP4 to GIF
I installed `ffmpeg` using brew and then used a command like this:
```shell
ffmpeg -i firststep.mp4 -filter_complex "[0:v] palettegen" firststep.palette.png
ffmpeg -i firststep.mp4 -i firststep.palette.png -filter_complex "[0:v][1:v] paletteuse" -r 10 firststep.gif
```
