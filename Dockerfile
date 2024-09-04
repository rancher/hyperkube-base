FROM ubuntu:22.04

ARG ARCH=amd64

COPY scripts/hyperkube /hyperkube
COPY scripts/iptables-wrapper-installer.sh /usr/sbin/iptables-wrapper-installer.sh

# In order to trick the upstream-provided script for iptables-wrapper-installer.sh into allowing us to do things the debian way, we need to link update-alternatives into sbin

RUN ln -s /usr/bin/update-alternatives /usr/sbin/update-alternatives 

# Adapted from: https://github.com/kubernetes/kubernetes/blob/release-1.17/build/debian-hyperkube-base/Dockerfile

RUN ln -s /hyperkube /apiserver \
 && ln -s /hyperkube /cloud-controller-manager \
 && ln -s /hyperkube /controller-manager \
 && ln -s /hyperkube /kubectl \
 && ln -s /hyperkube /kubelet \
 && ln -s /hyperkube /proxy \
 && ln -s /hyperkube /scheduler

# The samba-common, cifs-utils, and nfs-common packages depend on
# ucf, which itself depends on /bin/bash.
RUN echo "dash dash/sh boolean false" | debconf-set-selections
RUN DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash

RUN echo CACHEBUST>/dev/null \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get autoclean \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    apt-transport-https \
    arptables \
    ca-certificates \
    ceph-common \
    cifs-utils \
    conntrack \
    curl \
    e2fsprogs \
    xfsprogs \
    ebtables \
    ethtool \
    git \
    glusterfs-client \
    glusterfs-common \
    gnupg1 \
    iproute2 \
    ipset \
    iptables \
    iputils-ping \
    jq \
    kmod \
    lsb-release \
    open-iscsi \
    openssh-client \
    procps \
    netbase \
    nfs-common \
    samba-common \
    socat \
    udev \
    util-linux \
    xfsprogs \
    zfsutils-linux \
    && AZ_REPO=$(lsb_release -cs) \
    && echo "deb [arch=${ARCH}] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" > \
    /etc/apt/sources.list.d/azure-cli.list \
    && curl -L https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && apt-get purge gnupg \
    && apt-get update \
    && apt-get install -y --no-install-recommends azure-cli \
    && apt-get clean -y \
    && rm -rf \
      /var/cache/debconf/* \
      /var/lib/apt/lists/* \
      /var/log/* \
      /tmp/* \
      /var/tmp/*

# iptables-wrapper-installer.sh uses `iptables-nft --version` to check whether iptables-nft exists, iptables-nft returns
# the error "protocol not supported" when being invoked in an emulated enviroment whose arch (for example, arm64)
# is different from the host (amd64). So we do the check ourselves before running iptables-wrapper-installer.sh.
RUN which iptables-legacy && which iptables-nft
RUN /usr/sbin/iptables-wrapper-installer.sh --no-sanity-check

ENTRYPOINT ["/hyperkube"]
