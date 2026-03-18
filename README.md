# edge-fleet-management
This repo contains all artifacts used in Portland Kubernetes usergroup meeting

## Building microshift bootc image
Images are automatically built in github actions pipeline but

### Base image
First we will build a base bootc image with flightctl agent in it

```sh
make base
```

### Build Microshift bootc image
Build the fedora bootc microshift image with flightctl agent

```sh
make microshift
```

### Overlay Cloud Init
Overlay microshift bootc image with cloudinit

```sh
make cloudinit
```

### Build AMI
Build AMI to test in cloud. Before we can make AMI we need to setup the AWS account with vmimport service role. Run ansible playbook as shown below.

```sh
export VAULT_SECRET=<redacted>

ansible-playbook --vault-password-file <(echo "$VAULT_SECRET") configure_aws.yml

```

Run command below to make AMI

```sh
make ami
```

### Create EKS Cluster to deploy flightctl

```sh
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Update kubeconfig
Run command below to update local kubeconfig file

```sh
aws eks update-kubeconfig --region us-west-2 --name edge-fleet-mgmt
```

### Install FlightCTL
Install [flightctl](https://github.com/flightctl/flightctl) on EKS cluster. FlightCTL allows us to manage edge devices as fleet. Supports kubernetes style gitops based declarative management.

```sh
helm install edge-manager --namespace flightctl --create-namespace deploy/helm/flightctl -f $HOME/github.com/rprakashg/edge-fleet-management/deploy/flightctl/values.yaml
```

### Install Keycloak

```sh
kubectl create namespace keycloak

kubectl apply -f keycloak.yaml -n keycloak

```

### Login to flightctl service
Ensure that you can login to flightctl service using the web interface. Once logged in define a new repository and repository sync to sync fleet resources from git repo.

### Setup flightctl CLI
First create a custom client in keycloak for CLI and then login to flightctl web and define a new authentication provider to allow login from CLI. Now you are ready to login to flightctl from cli

```sh
flightctl login https://api.flightctl.sandbox3174.opentlc.com --web -k --provider=flightctl-cli
```

Browser will open where you will be prompted to authenticate with keycloak and after successful login, CLI will be setup to interact with flightctl service

### Generate an Enrollment Certificate
Generate an enrollment certificate to be injected into the device for flightctl agent to enroll the device with flightctl service. Run command below to generate an enrollment certificate for devices

```sh
flightctl certificate request --signer=enrollment --expiration=365d --output=embedded > config.yaml
```

### Launch an EC2 instance 
Launch an EC2 instance using the AMI we created to demonstrate provisioning and enrollment into fleet

