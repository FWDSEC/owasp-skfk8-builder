# OWASP SKF K8 Builder Tools
This is the Github repo for the OWASP Vancouver talk: "Build more secure apps by harnessing the power of OWASP SKF & ASVS on Kubernetes".

# Overview
Gettig OWASP Secure Knowledge Framework up-and-running on a live Kubernetes clusters can be really challenging. 

The `kops.sh` contains a series of shell functions that are executed in order to create the 2x Kubernetes environments necessary to run the OWASP Secure Knowledge Framework in AWS.

Recently, the Kubernetes standard has changed around Igress deployment definitions (no longer beta!) and SKF is only working in Kubernetes `v1.18.20` (or earlier), and `v1.18.20` is is slated for End-of-Life.