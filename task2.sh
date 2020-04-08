#!/bin/bash
# Everis Challege Task2
# Cretated by Ciro Rosales Barreto
# Mail ingcrosales@gmail.com

#Crear un script bash o makefile, que acepte parámetros (CREATE, DESTROY y OUTPUT) con los siguientes pasos:
#Al ejecutar el bash se pedira uno de los 3 parametros, en caso no se especifique, se mostrará el mensaje 
if [ -z "$1" ]
then
echo "Usage:"
echo "./task2.sh <CREATE|DESTROY|OUTPUT>"
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

#GKE Cluster terraform file

cat > ./gkecluster.tf <<EOF
resource "google_container_cluster" "gke-cluster" {
  name               = "everis-challege-gke-cluster"
  network            = "default"
  location           = "$ZONE"
  initial_node_count = 1
}
EOF

#Crear una VM basada en Centos

cat > ./vminstance.tf <<EOF
resource "google_compute_instance" "default" {
  name         = "terraforminstance"
  machine_type = "n1-standard-1"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
    }
  }

  scratch_disk {
    interface = "SCSI"
  }

  network_interface {
    network = "default"
	access_config {
          // Ephemeral IP
        }
  }

}
EOF

terraform plan -out task2

terraform apply "task2"

pip install requests google-auth

#Instalar Jenkins en la VM (Puede ser Instalado con Docker o como Servicio, pero es importante que la instalación se realice a través de un playbook de ansible)


#Se Ingresa a la VM e instala de Ansible
gcloud compute ssh terraforminstance --zone=us-central1-a -- 'sudo yum install ansible -y'
gcloud compute ssh terraforminstance --zone=us-central1-a -- 'sudo mkdir /temp-files/'
gcloud compute ssh terraforminstance --zone=us-central1-a -- 'sudo chmod 777 /temp-files/'

#Creacion de playbook para la instalacion de Jenkins
cat > ./linux_jenkins.yml <<EOF
---
- name: Install Jenkins
  hosts: 127.0.0.1
  gather_facts: false
  become: true
  tasks:
    - name: Install yum
      yum:
        name:
          - wget
          - java-1.8.0-openjdk

    - name: Download jenkins.repo
      get_url:
        url: http://pkg.jenkins-ci.org/redhat-stable/jenkins.repo
        dest: /etc/yum.repos.d/jenkins.repo

    - name: Import Jenkins Key
      rpm_key:
        state: present
        key: https://jenkins-ci.org/redhat/jenkins-ci.org.key

    - name: Install Jenkins
      yum:
        name: jenkins
        state: present

    - name: Start & Enable Jenkins
      systemd:
        name: jenkins
        state: started
        enabled: true

    - name: Sleep for 30 seconds and continue with play
      wait_for: timeout=30

    - name: Get init password Jenkins
      shell: cat /var/lib/jenkins/secrets/initialAdminPassword
      changed_when: false
      register: result

    - name: Print init password Jenkins
      debug:
        var: result.stdout
EOF

gcloud compute scp linux_jenkins.yml terraforminstance:/temp-files --zone=us-central1-a

#Ejecucion de Ansible Playbook para instalacion de Jenkins
gcloud compute ssh terraforminstance --zone=us-central1-a -- 'ansible-playbook /temp-files/linux_jenkins.yml'


#descarga de Jenkins cli
gcloud compute ssh terraforminstance --zone=us-central1-a -- 'curl -L https://github.com/jenkins-zh/jenkins-cli/releases/latest/download/jcli-linux-amd64.tar.gz|tar xzv'

gcloud compute ssh terraforminstance --zone=us-central1-a -- 'sudo cp jcli /usr/local/bin/'

gcloud compute ssh terraforminstance --zone=us-central1-a -- 'sudo cp jcli /var/lib/jenkins/plugins/'

gcloud compute ssh terraforminstance --zone=us-central1-a -- 'sudo cp /var/lib/jenkins/secrets/initialAdminPassword /temp-files/'

gcloud compute ssh terraforminstance --zone=us-central1-a -- 'sudo chmod -R 777 /temp-files/'

#obtener token de Jenkins de la VM
gcloud compute scp terraforminstance:/temp-files/initialAdminPassword --zone=us-central1-a .

#Captura de Token Jenkins
JENKINSTOKEN=$(<initialAdminPassword)


#Configuracion de cli Jenkins

cat > ./jenkins-cli.yaml <<EOF
current: jenkinsServer
language: ""
jenkins_servers:
- name: jenkinsServer
  url: http://localhost:8080/
  username: admin
  token: $JENKINSTOKEN
  proxy: ""
  proxyAuth: ""
  insecureSkipVerify: true
  description: ""
preHooks: []
postHooks: []
pluginSuites: []
mirrors:
- name: default
  url: http://mirrors.jenkins.io/
- name: tsinghua
  url: https://mirrors.tuna.tsinghua.edu.cn/jenkins/
- name: huawei
  url: https://mirrors.huaweicloud.com/jenkins/
- name: tencent
  url: https://mirrors.cloud.tencent.com/jenkins/
EOF

#Colocando config de Jenkins cli

gcloud compute scp jenkins-cli.yaml terraforminstance:/temp-files --zone=us-central1-a

gcloud compute ssh terraforminstance --zone=us-central1-a -- 'sudo mv /temp-files/jenkins-cli.yaml /root/.jenkins-cli.yaml'

gcloud compute ssh terraforminstance --zone=us-central1-a -- './jcli config generate'


#Instalar plugins estándar de pipeline

gcloud compute ssh terraforminstance --zone=us-central1-a -- './var/lib/jenkins/plugins/jcli plugin download build-pipeline-plugin'

gcloud compute ssh terraforminstance --zone=us-central1-a -- './var/lib/jenkins/plugins/jcli plugin download pipeline-maven'


#Crear un sharedlib que pueda compilar maven.

#
###Pendiente de desarrollo###
#

#Crear un Job que haga uso del sharedlib para compilar exitosamente un proyecto java simple tipo “Hello World”

#
###Pendiente de desarrollo###
#

fi

#Inicia DESTROY

if [ $1 = 'DESTROY' ]
then

#Se borra la instancia creada
gcloud compute instances delete terraforminstance --zone=us-central1-a

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

