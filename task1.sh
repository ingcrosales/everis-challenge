#!/bin/bash
# Everis Challege Task1
# Cretated by Ciro Rosales Barreto
# Mail ingcrosales@gmail.com

if [ -z "$1" ]
then
echo "Usage:"
echo "./task1.sh <CREATE|DESTROY|OUTPUT>"
exit 1
fi

if [ $1 = 'CREATE' ]
then

echo -n "Enter your project name:"
read NAME

gcloud config set project $NAME

echo -n "Enter your Service Account Json File name, Example 'file.json':"
read FILE

echo -n "Enter your zone, Example 'europe-west1-b':"
read ZONE

cat > ./provider.tf <<EOF
provider "google" {
  credentials = "$FILE"
  project     = "$NAME"
  region      = "europe-west1"
}
EOF

terraform init

cat > ./gkecluster.tf <<EOF
resource "google_container_cluster" "gke-cluster" {
  name               = "everis-challege-gke-cluster"
  network            = "default"
  location           = "$ZONE"
  initial_node_count = 1
}
EOF

terraform plan -out task1

terraform apply "task1"

gcloud config set compute/zone $ZONE

gcloud container clusters get-credentials everis-challege-gke-cluster

cat > ./basic-ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: basic-ingress
spec:
  backend:
    serviceName: web
    servicePort: 8080
EOF

kubectl apply -f basic-ingress.yaml

cat > ./index.py <<EOF
import socket
from flask import Flask, request

app = Flask(__name__)

@app.route("/greetings")
def return_hostname():
    return "Hello world from {}".format(socket.gethostname())

@app.route("/square")
def square():
     x = request.args.get('x')
     number = int(x)
     return "number: {}, square: {}".format(number,number * number)


if __name__ == "__main__":
  app.run(host="0.0.0.0", port=int("8080"), debug=True)
EOF

cat > ./Dockerfile <<EOF
FROM python:alpine3.7
COPY . /app
WORKDIR /app
RUN pip install flask
EXPOSE 5000
CMD python ./index.py
EOF

echo -n "Enter a tag for Docker build:"
read BUILDNAME

docker build --tag $BUILDNAME .

docker build -t gcr.io/$NAME/mypythonapp .

gcloud auth configure-docker

docker push gcr.io/$NAME/mypythonapp

kubectl create deployment $BUILDNAME --image=gcr.io/$NAME/mypythonapp

kubectl expose deployment $BUILDNAME --type=LoadBalancer --port 80 --target-port 8080

fi

if [ $1 = 'DESTROY' ]
then

gcloud container clusters delete everis-challege-gke-cluster

fi

if [ $1 = 'OUTPUT' ]
then

gcloud container clusters list

kubectl get service

fi

