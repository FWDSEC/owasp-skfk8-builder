FROM golang

RUN git clone https://github.com/FWDSEC/owasp-skfk8-builder && cd owasp-skfk8-builder && source aws.skfk8.kops.sh
