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
helm install edge-manager --namespace flightctl  deploy/helm/flightctl -f $HOME/github.com/rprakashg/edge-fleet-management/deploy/flightctl/values.yaml
```

### Install Keycloak

```sh
kubectl create namespace keycloak

kubectl apply -f keycloak.yaml -n keycloak

```

### Login to flightctl service


### Generate an Enrollment Certificate


