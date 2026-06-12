# Generic CUDA/PyTorch image for audio and ML experiments.
#
# Alternative base images:
#   FROM runpod/pytorch:2.1.1-py3.10-cuda11.8.0-devel-ubuntu22.04
#   FROM pytorch/pytorch:2.2.2-cuda12.1-cudnn8-runtime
FROM pytorch/pytorch:2.2.2-cuda12.1-cudnn8-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /workspace

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    curl \
    git \
    libsndfile1 \
    make \
    openssh-client \
    openssh-server \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/sshd /root/.ssh \
    && chmod 700 /root/.ssh \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

COPY requirements.txt /tmp/requirements.txt
RUN python -m pip install --upgrade pip \
    && python -m pip install -r /tmp/requirements.txt \
    && rm -f /tmp/requirements.txt

COPY gpu-startup.sh /usr/local/bin/gpu-startup.sh
RUN chmod +x /usr/local/bin/gpu-startup.sh

EXPOSE 22

# Prepare SSH/W&B/repo bootstrap for hosted GPU environments, then keep alive.
CMD ["/usr/local/bin/gpu-startup.sh"]
