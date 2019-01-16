# Multistage docker build, requires docker 17.05

# builder stage
FROM nvidia/cuda:10.0-devel as builder

RUN set -ex && \
    apt-get update && \
    apt-get --no-install-recommends --yes install \
        libncurses5-dev \
        libncursesw5-dev \
        cmake \
        git \
        curl \
        libssl-dev \
        pkg-config

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

RUN git clone https://github.com/mimblewimble/grin-miner && cd grin-miner && git submodule update --init

RUN cd grin-miner && sed -i 's/^\(cuckoo_miner.*\)}/\1, features = ["build-cuda-plugins"] }/' Cargo.toml

RUN cd grin-miner && $HOME/.cargo/bin/cargo build --release

RUN cd grin-miner && curl https://gist.githubusercontent.com/Clearwood/60294c02702b6995e719ce8a1d4df218/raw/a08622f1740dbc129d594c2a816038398f214d06/install.sh > install.sh

# runtime stage
FROM nvidia/cuda:10.0-base

RUN set -ex && \
    apt-get update && \
    apt-get --no-install-recommends --yes install \
    libncurses5 \
    libncursesw5 \
    vim

COPY --from=builder /grin-miner/target/release/grin-miner /root/target/release/grin-miner
COPY --from=builder /grin-miner/target/release/plugins/* /root/target/release/plugins/
COPY --from=builder /grin-miner/grin-miner.toml /root/grin-miner.toml
COPY --from=builder /grin-miner/install.sh /root/install.sh

WORKDIR /root

RUN sed -i 's/stratum_server_addr.*/stratum_server_addr = "eu-west-stratum.grinmint.com:4416"/' grin-miner.toml
RUN sed -i 's/stratum_server_tls_enabled.*/stratum_server_tls_enabled = true/' grin-miner.toml
RUN chmod a+x install.sh
RUN export PATH=/root/target/release:$PATH
