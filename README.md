# GPU Audio Base Image

Generic CUDA/PyTorch base image for audio and machine learning experiments.

It includes common Python packages such as NumPy, pandas, scikit-learn, SciPy, librosa, soundfile, matplotlib, seaborn, Hydra, W&B, and Rich. It also includes Node.js for agent and JavaScript CLIs.

No project code, datasets, checkpoints, tokens, or secrets are included.

The image starts `sshd` on port 22, can register a team SSH public key, can optionally log in to W&B from an environment variable, creates the team workspace layout, and keeps the container alive for hosted GPU environments.

## Startup Environment

Optional environment variables:

```text
TEAM_PUBLIC_KEY=ssh-ed25519 AAAA...
WANDB_API_KEY=...
GITHUB_NAVY_AI_DEPLOY_KEY_B64=...
GITHUB_PREPROCESSING_DEPLOY_KEY_B64=...
WORKSPACE_ROOT=/workspace
DATA_DIR=/workspace/data
TEAM_BOOTSTRAP_PULL=safe
NAVY_AI_REPO=git@github.com-navy-ai:SJB3COM/navy-ai.git
PREPROCESSING_REPO=git@github.com-navy-ai-preprocessing:SJB3COM/navy-ai-data-preprocessing.git
PREPROCESSING_DIR=/workspace/navy-ai-data-preprocessing
```

For private repositories, pre-register separate deploy public keys in GitHub and provide the matching private keys as `GITHUB_NAVY_AI_DEPLOY_KEY_B64` and `GITHUB_PREPROCESSING_DEPLOY_KEY_B64` through the GPU provider's secret environment variables.

The startup script creates:

```text
/workspace/hothyun/navy-ai
/workspace/seayurre/navy-ai
/workspace/ybuser/navy-ai
/workspace/k0ykwon/navy-ai
/workspace/data
/workspace/navy-ai-data-preprocessing
```

Each `navy-ai` clone has a local Git author configured for that teammate. Existing clean worktrees are updated with `pull --ff-only` when `TEAM_BOOTSTRAP_PULL=safe`; dirty worktrees are fetched but not pulled.

Python packages are installed once into the image-level Python environment at build time. Team member repositories should use the image Python directly and should not create per-repository virtual environments by default.

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

## Elice Bootstrap Test Image

`Dockerfile.elice-test` is a deliberately minimal CUDA/Python image used to
test the public `navy-ai` Elice bootstrap script. It does not include PyTorch,
project repositories, W&B login, deploy keys, or the team workspace startup
logic.

Build it through GitHub Actions:

1. Open `Actions`.
2. Select `Build Docker Image`.
3. Click `Run workflow`.
4. Set:

```text
tag=elice-test
dockerfile=Dockerfile.elice-test
```

The image is published as:

```text
ghcr.io/sjb3com/gpu-audio-base:elice-test
```

RunPod test command:

```bash
docker run --gpus all --rm -it \
  -e TEAM_USER=hothyun \
  -e GITHUB_TOKEN='<github token>' \
  -e WANDB_API_KEY='<wandb api key>' \
  -e TORCH_INDEX_URL=https://download.pytorch.org/whl/cu118 \
  ghcr.io/sjb3com/gpu-audio-base:elice-test \
  bash -lc 'curl -fsSL https://<your-public-cdn-host>/elice_bootstrap.sh | bash'
```

After bootstrap:

```bash
cd /workspace/hothyun/navy-ai
make imports
make check
make smoke
make doctor
```
