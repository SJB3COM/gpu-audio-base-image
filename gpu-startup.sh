#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-git@github.com:SJB3COM/navy-ai.git}"
REPO_HTTPS_URL="${REPO_HTTPS_URL:-https://github.com/SJB3COM/navy-ai.git}"
BRANCH="${BRANCH:-main}"
WORKDIR="${WORKDIR:-/workspace/navy-ai}"
TEAM_PUBLIC_KEY="${TEAM_PUBLIC_KEY:-}"
GITHUB_HOST="${GITHUB_HOST:-github.com}"
GITHUB_KEY_PATH="${GITHUB_KEY_PATH:-/root/.ssh/github_navy_ai}"
AUTO_CLONE="${AUTO_CLONE:-1}"
RUN_BOOTSTRAP="${RUN_BOOTSTRAP:-1}"

log() {
  echo "[gpu-startup] $*"
}

mkdir -p /run/sshd /root/.ssh /workspace
chmod 700 /root/.ssh || true

if [[ -n "${TEAM_PUBLIC_KEY}" ]]; then
  touch /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys || true
  if grep -Fxq "${TEAM_PUBLIC_KEY}" /root/.ssh/authorized_keys; then
    log "TEAM_PUBLIC_KEY already exists in authorized_keys"
  else
    printf '%s\n' "${TEAM_PUBLIC_KEY}" >> /root/.ssh/authorized_keys
    log "Added TEAM_PUBLIC_KEY to authorized_keys"
  fi
else
  log "TEAM_PUBLIC_KEY not set; direct SSH may require manual authorized_keys setup"
fi

if pgrep -x sshd >/dev/null 2>&1; then
  log "sshd already running"
else
  /usr/sbin/sshd
  log "sshd started"
fi

if [[ -n "${GITHUB_DEPLOY_KEY_B64:-}" ]]; then
  log "Installing GitHub deploy key from GITHUB_DEPLOY_KEY_B64"
  printf '%s' "${GITHUB_DEPLOY_KEY_B64}" | tr -d '\r\n ' | base64 -d > "${GITHUB_KEY_PATH}"
  chmod 600 "${GITHUB_KEY_PATH}"
elif [[ ! -f "${GITHUB_KEY_PATH}" ]]; then
  log "Creating GitHub deploy key: ${GITHUB_KEY_PATH}"
  ssh-keygen -t ed25519 -C "gpu-server-github-deploy-key" -f "${GITHUB_KEY_PATH}" -N ""
  chmod 600 "${GITHUB_KEY_PATH}"
else
  log "Reusing existing GitHub deploy key: ${GITHUB_KEY_PATH}"
  chmod 600 "${GITHUB_KEY_PATH}" || true
fi

if [[ -f "${GITHUB_KEY_PATH}.pub" ]]; then
  chmod 644 "${GITHUB_KEY_PATH}.pub" || true
elif [[ -f "${GITHUB_KEY_PATH}" ]]; then
  ssh-keygen -y -f "${GITHUB_KEY_PATH}" > "${GITHUB_KEY_PATH}.pub" || log "Failed to derive GitHub deploy public key"
  chmod 644 "${GITHUB_KEY_PATH}.pub" || true
fi

cat > /root/.ssh/config <<EOF
Host ${GITHUB_HOST}
  HostName ${GITHUB_HOST}
  User git
  IdentityFile ${GITHUB_KEY_PATH}
  IdentitiesOnly yes
EOF
chmod 600 /root/.ssh/config

if ! ssh-keygen -F "${GITHUB_HOST}" >/dev/null 2>&1; then
  ssh-keyscan "${GITHUB_HOST}" >> /root/.ssh/known_hosts 2>/dev/null || true
  chmod 644 /root/.ssh/known_hosts || true
fi

if [[ -f "${GITHUB_KEY_PATH}.pub" ]]; then
  cat <<EOF

[gpu-startup] GitHub deploy public key:
------------------------------------------------------------
$(cat "${GITHUB_KEY_PATH}.pub")
------------------------------------------------------------
Add this to:
  SJB3COM/navy-ai -> Settings -> Deploy keys -> Add deploy key
Recommended:
  Allow write access: off
EOF
fi

if command -v wandb >/dev/null 2>&1; then
  if [[ -n "${WANDB_API_KEY:-}" ]]; then
    wandb login --relogin "${WANDB_API_KEY}" || log "W&B login failed"
  else
    log "WANDB_API_KEY not set; run 'wandb login' later if needed"
  fi
else
  log "wandb CLI not found"
fi

clone_or_update_with_ssh() {
  if [[ -d "${WORKDIR}/.git" ]]; then
    log "Updating existing repo: ${WORKDIR}"
    git -C "${WORKDIR}" fetch --all --prune
  else
    log "Cloning repo with SSH: ${REPO_URL}"
    mkdir -p "$(dirname "${WORKDIR}")"
    git clone "${REPO_URL}" "${WORKDIR}"
  fi
}

clone_or_update_with_token() {
  local token_url
  token_url="${REPO_HTTPS_URL/https:\/\//https:\/\/x-access-token:${GITHUB_TOKEN}@}"
  if [[ -d "${WORKDIR}/.git" ]]; then
    log "Updating existing repo with HTTPS token: ${WORKDIR}"
    git -C "${WORKDIR}" fetch --all --prune
  else
    log "Cloning repo with HTTPS token"
    mkdir -p "$(dirname "${WORKDIR}")"
    git clone "${token_url}" "${WORKDIR}"
  fi
}

if [[ "${AUTO_CLONE}" == "1" ]]; then
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    clone_or_update_with_token || log "Git clone/update with token failed"
  else
    clone_or_update_with_ssh || log "Git clone/update with SSH failed; add deploy key above, then retry manually"
  fi

  if [[ -d "${WORKDIR}/.git" ]]; then
    cd "${WORKDIR}"
    if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
      git checkout "${BRANCH}" || true
    else
      git checkout -B "${BRANCH}" "origin/${BRANCH}" || true
    fi
    git pull --ff-only origin "${BRANCH}" || true

    if [[ "${RUN_BOOTSTRAP}" == "1" && -x "./scripts/bootstrap_competition_server.sh" ]]; then
      ./scripts/bootstrap_competition_server.sh || log "bootstrap_competition_server.sh failed"
    fi
  fi
else
  log "AUTO_CLONE=0; skipping repo clone"
fi

log "Ready. Keeping container alive."
tail -f /dev/null
