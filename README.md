# GPU Audio Base Image

Generic CUDA/PyTorch base image for audio and machine learning experiments.

It includes common Python packages such as NumPy, pandas, scikit-learn, SciPy, librosa, soundfile, matplotlib, seaborn, Hydra, W&B, and Rich.

No project code, datasets, checkpoints, tokens, or secrets are included.

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
