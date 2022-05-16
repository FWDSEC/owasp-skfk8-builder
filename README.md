# OWASP SKF K8 Builder Tools
This is the Github repo for the OWASP Vancouver talk: "Build more secure apps by harnessing the power of OWASP SKF & ASVS on Kubernetes".

To get started clone this repository, open a terminal window into the cloned folder, and run `source aws.skfk8.kops.sh`. You will want to `export AWS_PROFILE=XYZ` to the appropriate profile that can create an IAM user and IAM group to create/destroy the K8s clusters (labs/demo).  

## Tools Need to Build (Linux/MacOS/...)
1. AWS cli
2. kubectl
3. kops
4. helm
5. terraform
6. jq

# Overview
Gettig OWASP Secure Knowledge Framework up-and-running on a live Kubernetes clusters can be really challenging. 

The `aws.skfk8.kops.sh` contains a series of shell functions that are executed in order to create the 2x Kubernetes environments necessary to run the OWASP Secure Knowledge Framework in AWS.

Recently, the Kubernetes standard has changed around NetworkIgress deployment definitions (no longer beta!) and currently SKF is only working in Kubernetes `v1.18.20` (or earlier), and `v1.18.20` is is slated for End-of-Life.

Code changes to SKF are required because the Python code that deploys various SKF Labs uses the K8S API and assumes the Beta API. Using the `skf/ingress.1.22.yaml` one can deploy to newer kubernetes however the lab deployments fail.
