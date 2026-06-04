# Build Stage
FROM ubuntu:22.04 AS builder

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y cmake clang curl

RUN curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo install cargo-fuzz

ADD . /bit-vec
WORKDIR /bit-vec

RUN cd fuzz && cargo fuzz build bitvec-fuzz

# Package Stage
FROM ubuntu:22.04

COPY --from=builder /bit-vec/fuzz/target/x86_64-unknown-linux-gnu/release/bitvec-fuzz /
