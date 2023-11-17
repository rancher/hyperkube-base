ARCH ?=amd64
ALL_ARCH = amd64 arm64

IMAGE ?= docker.io/oats87/hyperkube-base
TAG ?= v0.0.1

BASEIMAGE ?= ubuntu:22.04
IPTWI_VERSION ?= v2
TEMP_DIR:=$(shell mktemp -d)

all: all-push

sub-build-%:
	$(MAKE) ARCH=$* build

all-build: $(addprefix sub-build-,$(ALL_ARCH))

sub-push-image-%:
	$(MAKE) ARCH=$* push

all-push-images: $(addprefix sub-push-image-,$(ALL_ARCH))

all-push: all-push-images push-manifest

scripts/iptables-wrapper-installer.sh:
	mkdir -p scripts/
	cd scripts/ && curl -sSLO --retry 5 https://raw.githubusercontent.com/kubernetes-sigs/iptables-wrappers/${IPTWI_VERSION}/iptables-wrapper-installer.sh && chmod +x iptables-wrapper-installer.sh

clean:
	rm -f scripts/iptables-wrapper-installer.sh

build: clean scripts/iptables-wrapper-installer.sh
	docker build --pull --build-arg ARCH=${ARCH} -t $(IMAGE):$(TAG)-linux-$(ARCH) .

push: build
	docker push $(IMAGE):$(TAG)-$(ARCH)

.PHONY: all build push clean all-build all-push-images all-push

.DEFAULT_GOAL := build
