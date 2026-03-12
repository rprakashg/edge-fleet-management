# edge-fleet-management
This repo contains all artifacts used in Portland Kubernetes usergroup meeting

## Building microshift bootc image
Images are automatically built in github actions pipeline but

### Base image
First we will build a base bootc image with flightctl agent in it

```sh
make base
```

Build the fedora bootc microshift image with flightctl agent

```sh
make microshift
```

Overlay microshift bootc image with cloudinit

```sh
make cloudinit
```

