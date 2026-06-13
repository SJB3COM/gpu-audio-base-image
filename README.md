# GPU Audio Base Image

Generic CUDA/PyTorch base image for audio and machine learning experiments.

It includes common Python packages such as NumPy, pandas, scikit-learn, SciPy, librosa, soundfile, matplotlib, seaborn, Hydra, W&B, and Rich. It also includes Node.js for agent and JavaScript CLIs.

No project code, datasets, checkpoints, tokens, or secrets are included.

The image starts `sshd` on port 22, can register a team SSH public key, can optionally log in to W&B from an environment variable, and keeps the container alive for hosted GPU environments.

## Startup Environment

Optional environment variables:

```text
TEAM_PUBLIC_KEY=ssh-ed25519 AAAA...
WANDB_API_KEY=...
GITHUB_DEPLOY_KEY_B64=...
REPO_URL=git@github.com:SJB3COM/navy-ai.git
BRANCH=main
WORKDIR=/workspace/navy-ai
AUTO_CLONE=1
RUN_BOOTSTRAP=1
```

For private repositories, pre-register the deploy public key in GitHub and provide the matching private key as `GITHUB_DEPLOY_KEY_B64` through the GPU provider's secret environment variables. A read-only `GITHUB_TOKEN` also works, but SSH deploy keys are preferred for this image.

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
  bash -lc "python -c \"import numpy, pandas, librosa, soundfile, wandb, hydra, torch; print('imports ok')\" && node --version && npm --version"
```

On a GPU Docker host:

```bash
docker run --gpus all --rm ghcr.io/sjb3com/gpu-audio-base:latest \
  python -c "import torch; print(torch.__version__); print(torch.cuda.is_available())"
```
