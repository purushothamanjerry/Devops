FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openssh-server \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /var/run/sshd

RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config

RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh
COPY authorized_keys /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
