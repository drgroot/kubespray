# ideally, make a separate image for spark
FROM ghcr.io/catthehacker/ubuntu:act-latest
ARG MC_VERSION=RELEASE.2025-08-13T08-35-41Z

RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub |    sudo apt-key add - \
    && echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /tmp/google.list \
    && sudo mv /tmp/google.list /etc/apt/sources.list.d/google.list

RUN curl -fsSLo /tmp/helm-v3.17.3-linux-amd64.tar.gz https://get.helm.sh/helm-v3.17.3-linux-amd64.tar.gz && \
    curl -fsSLo /tmp/helm-v3.17.3-linux-amd64.tar.gz.sha256sum https://get.helm.sh/helm-v3.17.3-linux-amd64.tar.gz.sha256sum && \
    cd /tmp && sha256sum --check helm-v3.17.3-linux-amd64.tar.gz.sha256sum && \
    tar -xzf /tmp/helm-v3.17.3-linux-amd64.tar.gz -C /tmp && \
    install -o root -g root -m 0755 /tmp/linux-amd64/helm /usr/local/bin/helm && \
    rm -rf /tmp/helm-v3.17.3-linux-amd64.tar.gz /tmp/helm-v3.17.3-linux-amd64.tar.gz.sha256sum /tmp/linux-amd64

RUN MC_ASSET="mc.linux-amd64.${MC_VERSION}" && \
    curl -fsSLo "/tmp/${MC_ASSET}" "https://github.com/minio/mc/releases/download/${MC_VERSION}/${MC_ASSET}" && \
    curl -fsSLo "/tmp/${MC_ASSET}.sha256sum" "https://github.com/minio/mc/releases/download/${MC_VERSION}/${MC_ASSET}.sha256sum" && \
    cd /tmp && echo "$(cut -d ' ' -f1 "${MC_ASSET}.sha256sum")  ${MC_ASSET}" | sha256sum --check && \
    install -m 0755 "${MC_ASSET}" /usr/local/bin/mc && \
    rm "${MC_ASSET}" "${MC_ASSET}.sha256sum"

RUN curl https://github.com/official-stockfish/Stockfish/releases/download/sf_16/stockfish-ubuntu-x86-64-modern.tar -L -o /tmp/stockfish.tar && \
    tar -xvf /tmp/stockfish.tar -C /tmp && \
    mv /tmp/stockfish/stockfish-ubuntu-x86-64-modern /bin/stockfish && \
    chmod +x /bin/stockfish && \
    rm -rf /tmp/stockfish*

RUN KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)" && \
    curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    curl -fsSLo /tmp/kubectl.sha256 "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256" && \
    echo "$(cat /tmp/kubectl.sha256)  /tmp/kubectl" | sha256sum --check && \
    install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl && \
    rm /tmp/kubectl /tmp/kubectl.sha256

RUN \
  apt-get update && \
  apt-get install -y \
    google-chrome-stable \ 
    git \
    skopeo

RUN git config --global advice.diverging false
