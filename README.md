# edge-fleet-management
This repo contains all artifacts used in Portland Kubernetes usergroup meeting

## Building microshift bootc image
Images are automatically built in github actions pipeline but

### Base image
First we will build a base bootc image with flightctl agent in it

```sh
podman build -t fedora-bootc-base:latest .
```

### Build Microshift OKD RPM Container

First clone this git [repo](https://github.com/microshift-io/microshift) as shown in command below

```sh
clone github.com/microshift-io/microshift
```

Build the microshift OKD RPMs image

```sh
make srpm
```

Tag and push the SRPM image to registry

```sh
sudo podman tag localhost/microshift-okd-srpm:latest <registry>/microshift-okd-srpm:latest
sudo podman push <registry>/microshift-okd-srpm:latest
```

Build microshift RPM image

```sh
make rpm SRPM_IMAGE=<registry>/microshift-okd-srpm:latest
```

Tag and Push the Microshift OKD RPM image to registry

```sh
sudo podman tag localhost/microshift-okd-rpm:latest <registry>/microshift-okd-rpm:latest
sudo podman push <registry>/microshift-okd-rpm:latest 
```

Build the fedora bootc microshift image with flightctl agent

```sh


```

