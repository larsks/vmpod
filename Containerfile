FROM docker.io/alpine:latest AS firectl

RUN apk add alpine-sdk git go
WORKDIR /build
RUN git clone https://github.com/firecracker-microvm/firectl
WORKDIR firectl
RUN make

FROM firectl AS firecracker

RUN apk add rust cargo clang clang-libclang linux-headers cmake
WORKDIR /build
RUN git clone https://github.com/firecracker-microvm/firecracker
WORKDIR firecracker
COPY 0001-Don-t-spam-console-with-failed-to-write-to-tap-messa.patch ./
RUN git config --global user.email build ; git config --global user.name build; \
  git am 0001-Don-t-spam-console-with-failed-to-write-to-tap-messa.patch
RUN cargo build --release


FROM docker.io/alpine:latest

RUN apk add iproute2 tcpdump bash
RUN apk add qemu qemu-bridge-helper qemu-img qemu-system-x86_64

COPY --from=firectl /build/firectl/firectl /usr/local/bin/
COPY --from=firecracker /build/firecracker/build/cargo_target/release/firecracker /usr/local/bin/
COPY --from=firecracker /usr/lib/libgcc_s.so.1 /usr/lib/

COPY run-firecracker-vm.sh /run-firecracker-vm.sh
COPY run-qemu-vm.sh /run-qemu-vm.sh
#CMD ["bash", "/run-firecracker-vm.sh"]
CMD ["bash", "/run-qemu-vm.sh"]
