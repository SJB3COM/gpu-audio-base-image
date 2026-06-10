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
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/requirements.txt
RUN python -m pip install --upgrade pip \
    && python -m pip install -r /tmp/requirements.txt \
    && rm -f /tmp/requirements.txt

# Keep the container alive so RunPod can attach terminals and VS Code Remote SSH.
CMD ["bash", "-lc", "sleep infinity"]
