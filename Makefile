# Options used in the 'rpm' target
USHIFT_GITREF ?= main
OKD_VERSION_TAG ?= $$(./images/fedora-bootc-microshift/scripts/get_version.sh latest-amd64)
REGISTRY ?= quay.io/rprakashg
BOOTC_BASE_IMAGE ?= fedora-bootc-base
BOOTC_BASE_IMAGE_TAG ?= latest
BOOTC_MICROSHIFT_IMAGE ?= fedora-bootc-microshift
BOOTC_MICROSHIFT_IMAGE_TAG ?= latest

.PHONY: base
base:
	podman build \
		-t ${BOOTC_BASE_IMAGE}:${BOOTC_BASE_IMAGE_TAG} \
		-f images/fedora-bootc-base/Containerfile images/fedora-bootc-base

	podman tag ${BOOTC_BASE_IMAGE}:${BOOTC_BASE_IMAGE_TAG} ${REGISTRY}/${BOOTC_BASE_IMAGE}:${BOOTC_BASE_IMAGE_TAG}

	podman push ${REGISTRY}/${BOOTC_BASE_IMAGE}:${BOOTC_BASE_IMAGE_TAG}

.PHONY: microshift
microshift:
	sudo podman build \
		-t ${BOOTC_MICROSHIFT_IMAGE}:${BOOTC_MICROSHIFT_IMAGE_TAG} \
		--ulimit nofile=524288:524288 \
		--label microshift.ref="${USHIFT_GITREF}" \
		--label okd.version="${OKD_VERSION_TAG}" \
		--build-arg BASE_IMAGE="${REGISTRY}/${BOOTC_BASE_IMAGE}" \
		--build-arg BASE_IMAGE_TAG="${BOOTC_BASE_IMAGE_TAG}" \
		--env EMBED_CONTAINER_IMAGES="0" \
		-f images/fedora-bootc-microshift/Containerfile images/fedora-bootc-microshift

	sudo podman tag ${BOOTC_MICROSHIFT_IMAGE}:${BOOTC_MICROSHIFT_IMAGE_TAG} ${REGISTRY}/${BOOTC_MICROSHIFT_IMAGE}:${BOOTC_MICROSHIFT_IMAGE_TAG}

	sudo podman push ${REGISTRY}/${BOOTC_MICROSHIFT_IMAGE}:${BOOTC_MICROSHIFT_IMAGE_TAG}
.PHONY: cloudinit
cloudinit:
	echo "Overlaying cloud init on fedora bootc base image with flightctl agent"
	podman build \
		-t ${BOOTC_BASE_IMAGE}:aws \
		--build-arg base="${BOOTC_BASE_IMAGE}:${BOOTC_BASE_IMAGE_TAG}" \
		-f images/cloud-init/Containerfile images/cloud-init
	
	podman tag ${BOOTC_BASE_IMAGE}:aws ${REGISTRY}/${BOOTC_BASE_IMAGE}:aws
	podman push ${REGISTRY}/${BOOTC_BASE_IMAGE}:aws

	echo "Overlaying cloud init on fedora bootc image with flightctl agent and microshift"
	podman build \
		-t ${BOOTC_MICROSHIFT_IMAGE}:aws \
		--build-arg base="${BOOTC_MICROSHIFT_IMAGE}:${BOOTC_MICROSHIFT_IMAGE_TAG}" \
		-f images/cloud-init/Containerfile images/cloud-init

	podman tag ${BOOTC_MICROSHIFT_IMAGE}:aws ${REGISTRY}/${BOOTC_MICROSHIFT_IMAGE}:aws

	podman push ${REGISTRY}/${BOOTC_MICROSHIFT_IMAGE}:aws

.PHONY: iso
iso:
	echo "Making iso using BiB"

.PHONY: ami
ami:
	echo "Making AWS AMI using BiB"
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
		--aws-ami-name fedora-bootc-microshift-ami \
		--aws-bucket bootc-images \
		--aws-region us-west-2 \
		${REGISTRY}/${BOOTC_MICROSHIFT_IMAGE}:aws
