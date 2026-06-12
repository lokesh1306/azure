FROM ghcr.io/runatlantis/atlantis:v0.43.0

USER root

ARG TARGETARCH
ARG TERRAGRUNT_VERSION=1.0.5
ARG SOPS_VERSION=3.13.1
ARG KUBELOGIN_VERSION=0.1.4
ARG YQ_VERSION=4.44.3

RUN apk add --no-cache jq openssl curl bash py3-pip ca-certificates gcc musl-dev libffi-dev openssl-dev python3-dev && \
    pip install --no-cache-dir --break-system-packages azure-cli && \
    wget -q https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_${TARGETARCH} \
      -O /usr/local/bin/terragrunt && chmod +x /usr/local/bin/terragrunt && \
    wget -q https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.${TARGETARCH} \
      -O /usr/local/bin/sops && chmod +x /usr/local/bin/sops && \
    wget -q https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${TARGETARCH} \
      -O /usr/local/bin/yq && chmod +x /usr/local/bin/yq && \
    wget -q https://github.com/Azure/kubelogin/releases/download/v${KUBELOGIN_VERSION}/kubelogin-linux-${TARGETARCH}.zip \
      -O /tmp/kubelogin.zip && \
    unzip /tmp/kubelogin.zip -d /tmp && \
    mv /tmp/bin/linux_${TARGETARCH}/kubelogin /usr/local/bin/kubelogin && \
    chmod +x /usr/local/bin/kubelogin && \
    rm -rf /tmp/kubelogin.zip /tmp/bin

USER atlantis
