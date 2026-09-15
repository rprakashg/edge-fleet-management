# Options used in the 'rpm' target
USHIFT_GITREF ?= main
OKD_VERSION_TAG ?= $$(./images/fedora-bootc-microshift/scripts/get_version.sh latest-amd64)
REGISTRY ?= quay.io/rprakashg
BOOTC_BASE_IMAGE ?= fedora-bootc-base
BOOTC_BASE_IMAGE_TAG ?= latest
BOOTC_MICROSHIFT_IMAGE ?= fedora-bootc-microshift
BOOTC_MICROSHIFT_IMAGE_TAG ?= latest
EMBED_CONTAINER_IMAGES ?=0
AMI_NAME ?=bootc-device-base
BUCKET_NAME ?=bootc-amis-demo
AWS_REGION ?=ap-south-1

.PHONY: base
base:
	podman build \
		--arch amd64 \
		-t ${BOOTC_BASE_IMAGE}:${BOOTC_BASE_IMAGE_TAG} \
		-f images/fedora-bootc-base/Containerfile images/fedora-bootc-base

	podman tag ${BOOTC_BASE_IMAGE}:${BOOTC_BASE_IMAGE_TAG} ${REGISTRY}/${BOOTC_BASE_IMAGE}:${BOOTC_BASE_IMAGE_TAG}

	podman push ${REGISTRY}/${BOOTC_BASE_IMAGE}:${BOOTC_BASE_IMAGE_TAG}

.PHONY: microshift
microshift:
	podman build \
		--arch amd64 \
		-t ${BOOTC_MICROSHIFT_IMAGE}:${BOOTC_MICROSHIFT_IMAGE_TAG} \
		--ulimit nofile=524288:524288 \
		--label microshift.ref="${USHIFT_GITREF}" \
		--label okd.version="${OKD_VERSION_TAG}" \
		--build-arg BASE_IMAGE="${REGISTRY}/${BOOTC_BASE_IMAGE}" \
		--build-arg BASE_IMAGE_TAG="${BOOTC_BASE_IMAGE_TAG}" \
		--env EMBED_CONTAINER_IMAGES="${EMBED_CONTAINER_IMAGES}" \
		-f images/fedora-bootc-microshift/Containerfile images/fedora-bootc-microshift

	podman tag ${BOOTC_MICROSHIFT_IMAGE}:${BOOTC_MICROSHIFT_IMAGE_TAG} ${REGISTRY}/${BOOTC_MICROSHIFT_IMAGE}:${BOOTC_MICROSHIFT_IMAGE_TAG}

	podman push ${REGISTRY}/${BOOTC_MICROSHIFT_IMAGE}:${BOOTC_MICROSHIFT_IMAGE_TAG}

.PHONY: cloudinit
cloudinit:
	echo "Overlaying cloud init packages"
	podman build \
		--arch amd64 \
		-t ${REGISTRY}/${BOOTC_BASE_IMAGE}:aws \
		--build-arg base="${REGISTRY}/${BOOTC_BASE_IMAGE}:${BOOTC_BASE_IMAGE_TAG}" \
		-f images/cloud-init/Containerfile images/cloud-init
	podman push ${REGISTRY}/${BOOTC_BASE_IMAGE}:aws

.PHONY: fido-device
fido-device:
	echo "Building fido device image"
	podman build \
		--arch amd64 \
		-t fido-device:latest \
		--build-arg FROM=${REGISTRY}/${BOOTC_BASE_IMAGE}:${BOOTC_BASE_IMAGE_TAG} \
		-f images/fido-device/Containerfile images/fido-device
	
	echo "Tagging and pushing image to registry"
	podman tag fido-device:latest ${REGISTRY}/fido-device:latest
	podman push ${REGISTRY}/fido-device:latest
.PHONY: iso
iso:
	echo "Making iso using BiB - Not Implemented"

.PHONY: ami
ami:
	echo "First pulling bootc image down"
	sudo podman pull ${REGISTRY}/${BOOTC_BASE_IMAGE}:aws
	
	echo "Making AWS AMI for bootc base image using BiB"
	sudo podman run \
		--rm \
		-it \
		--privileged \
		--pull=newer \
		--security-opt label=type:unconfined_t \
		-v ${HOME}/.aws:/root/.aws:ro \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		--env AWS_PROFILE=default \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type ami \
		--rootfs xfs \
		--aws-ami-name ${AMI_NAME} \
		--aws-bucket ${BUCKET_NAME} \
		--aws-region ${AWS_REGION} \
		${REGISTRY}/${BOOTC_BASE_IMAGE}:aws