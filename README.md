# GPU Audio Base Image

Generic CUDA/PyTorch base image for audio and machine learning experiments.

It includes common Python packages such as NumPy, pandas, scikit-learn, SciPy, librosa, soundfile, matplotlib, seaborn, Hydra, W&B, and Rich.

No project code, datasets, checkpoints, tokens, or secrets are included.

The image starts `sshd` on port 22, can register a team SSH public key, can optionally log in to W&B from an environment variable, and keeps the container alive for hosted GPU environments.

## Startup Environment

Optional environment variables:

```text
TEAM_PUBLIC_KEY=ssh-ed25519 AAAA...
WANDB_API_KEY=...
REPO_URL=git@github.com:SJB3COM/navy-ai.git
BRANCH=main
WORKDIR=/workspace/navy-ai
AUTO_CLONE=1
RUN_BOOTSTRAP=1
```

For private repositories, either add the printed deploy public key to GitHub Deploy Keys after startup, or provide a read-only `GITHUB_TOKEN`/`GITHUB_DEPLOY_KEY_B64` as a secret environment variable.

## Build

This repository builds the image manually through GitHub Actions.

1. Open the `Actions` tab.
2. Select `Build Docker Image`.
3. Click `Run workflow`.
4. Use `latest` or a custom tag.

The image is published as:

```text
ghcr.io/sjb3com/gpu-audio-base:latest
```

If Docker Hub temporarily fails or rate-limits base image pulls, rerun the workflow. For more reliable pulls, add repository secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`, then set repository variable `DOCKERHUB_LOGIN_ENABLED=true`.

## Smoke Check

```bash
docker run --rm ghcr.io/sjb3com/gpu-audio-base:latest \
  python -c "import numpy, pandas, librosa, soundfile, wandb, hydra, torch; print('imports ok')"
```

On a GPU Docker host:

```bash
docker run --gpus all --rm ghcr.io/sjb3com/gpu-audio-base:latest \
  python -c "import torch; print(torch.__version__); print(torch.cuda.is_available())"
```
