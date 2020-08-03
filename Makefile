# Build the hyperkube base image. This image is used to build the hyperkube image.
#
# Usage:
#   [ARCH=amd64] [REGISTRY="staging-k8s.gcr.io"] make (build|push)

REGISTRY?=docker.io/oats87
IMAGE?=$(REGISTRY)/hyperkube-base
TAG?=v0.0.1
ARCH?=amd64
ALL_ARCH = amd64 arm arm64 ppc64le s390x

BASE_REGISTRY?=docker.io
BASEIMAGE?=$(BASE_REGISTRY)/ubuntu:20.04

CNI_VERSION?=v0.8.6

TEMP_DIR:=$(shell mktemp -d)
CNI_TARBALL=cni-plugins-linux-$(ARCH)-$(CNI_VERSION).tgz

# This option is for running docker manifest command
export DOCKER_CLI_EXPERIMENTAL := enabled

SUDO=$(if $(filter 0,$(shell id -u)),,sudo)

.PHONY: all build push clean all-build all-push-images all-push push-manifest

all: all-push

sub-build-%:
	$(MAKE) ARCH=$* build

all-build: $(addprefix sub-build-,$(ALL_ARCH))

sub-push-image-%:
	$(MAKE) ARCH=$* push

all-push-images: $(addprefix sub-push-image-,$(ALL_ARCH))

all-push: all-push-images push-manifest

push-manifest:
	docker manifest create --amend $(IMAGE):$(TAG) $(shell echo $(ALL_ARCH) | sed -e "s~[^ ]*~$(IMAGE)\-&:$(TAG)~g")
	@for arch in $(ALL_ARCH); do docker manifest annotate --arch $${arch} ${IMAGE}:${TAG} ${IMAGE}:${TAG}-$${arch}; done
	docker manifest push --purge ${IMAGE}:${TAG}

cni-tars/$(CNI_TARBALL):
	mkdir -p cni-tars/
	cd cni-tars/ && curl -sSLO --retry 5 https://storage.googleapis.com/k8s-artifacts-cni/release/${CNI_VERSION}/${CNI_TARBALL}

clean:
	rm -rf cni-tars/

build: cni-tars/$(CNI_TARBALL)
	cp Dockerfile $(TEMP_DIR)
	cp -r scripts $(TEMP_DIR)
	cd $(TEMP_DIR) && sed -i.back "s|BASEIMAGE|$(BASEIMAGE)|g" Dockerfile

	mkdir -p ${TEMP_DIR}/cni-bin/bin
	tar -xz -C ${TEMP_DIR}/cni-bin/bin -f "cni-tars/${CNI_TARBALL}"

ifneq ($(ARCH),amd64)
	# Register /usr/bin/qemu-ARCH-static as the handler for non-x86 binaries in the kernel
	$(SUDO) ../../third_party/multiarch/qemu-user-static/register/register.sh --reset
endif
	docker build --pull -t $(IMAGE):$(TAG)-$(ARCH) $(TEMP_DIR)
	rm -rf $(TEMP_DIR)

push: build
	docker push $(IMAGE):$(TAG)-$(ARCH)
