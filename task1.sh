#!/bin/bash
# Everis Challege Task1
# Cretated by Ciro Rosales Barreto
# Mail ingcrosales@gmail.com

#Crear un script bash o makefile, que acepte parámetros (CREATE, DESTROY y OUTPUT) con los siguientes pasos:
#Al ejecutar el bash se pedira uno de los 3 parametros, en caso no se especifique, se mostrará el mensaje 
if [ -z "$1" ]
then
echo "Usage:"
echo "./task1.sh <CREATE|DESTROY|OUTPUT>"
exit 1
fi

#Inicia CREATE

if [ $1 = 'CREATE' ]
then

#Exportar las variables necesarias para crear recursos en GCP (utilizar las credenciales previamente descargadas).
#Cada variable será solicitada al usuario durante el proceso.
echo -n "Enter your project name:"
read NAME

gcloud config set project $NAME

echo -n "Enter your Service Account Json File name, Example 'file.json':"
read FILE

echo -n "Enter your zone, Example 'europe-west1-b':"
read ZONE

#Utilizar terraform o pulumi para crear un Cluster de Kubernetes de un solo nodo (GKE).
#Se generan los archivos necesarios para crear el cluster con terraform

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

#Instalar ingress controller en el Cluster de k8s.
#Se crea un ingress controller libre a modo de prueba del GKE

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

#Se Genera el archivo con las aplicaciones en python
#/greetings: message —> “Hello World from $HOSTNAME”.
#/square: message —>  number: X, square: Y, donde Y es el cuadrado de X. Se espera un response con el cuadrado.

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

#Crea una imagen docker para desplegar una aplicación tipo RESTFUL API, basada en python que responda a siguientes dos recursos:
#Se crea el Dockerfile copiando el proyecto con las aplicaciones python

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

#Desplegar la imagen con los objetos mínimos necesarios (no utilizar pods ni replicasets directamente).
#El servicio debe poder ser consumido públicamente 

docker build --tag $BUILDNAME .

docker build -t gcr.io/$NAME/mypythonapp .

gcloud auth configure-docker

docker push gcr.io/$NAME/mypythonapp

kubectl create deployment $BUILDNAME --image=gcr.io/$NAME/mypythonapp

#Se crea el Ingress Controller para acceder al servicio públicamente

kubectl expose deployment $BUILDNAME --type=LoadBalancer --port 80 --target-port 8080

fi

#Inicia DESTROY

if [ $1 = 'DESTROY' ]
then

echo -n "Enter zone of your GKE, Example 'europe-west1-b':"
read ZONE

#Se destruye el container GKE
gcloud container clusters delete everis-challege-gke-cluster --zone=$ZONE 

fi

#Inicia OUTPUT

if [ $1 = 'OUTPUT' ]
then

#lista los cluster disponibles
gcloud container clusters list

#muestra el servicio con la ip de acceso
kubectl get service

fi

