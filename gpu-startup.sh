#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/workspace}"
DATA_DIR="${DATA_DIR:-${WORKSPACE_ROOT}/data}"
TEAM_BOOTSTRAP_PULL="${TEAM_BOOTSTRAP_PULL:-safe}" # safe, always, never
TEAM_PUBLIC_KEY="${TEAM_PUBLIC_KEY:-}"

NAVY_AI_REPO="${NAVY_AI_REPO:-git@github.com-navy-ai:SJB3COM/navy-ai.git}"
PREPROCESSING_REPO="${PREPROCESSING_REPO:-git@github.com-navy-ai-preprocessing:SJB3COM/navy-ai-data-preprocessing.git}"
PREPROCESSING_DIR="${PREPROCESSING_DIR:-${WORKSPACE_ROOT}/navy-ai-data-preprocessing}"

NAVY_AI_KEY_B64="${GITHUB_NAVY_AI_DEPLOY_KEY_B64:-}"
PREPROCESSING_KEY_B64="${GITHUB_PREPROCESSING_DEPLOY_KEY_B64:-}"

log() {
  echo "[gpu-startup] $*"
}

fail() {
  echo "[gpu-startup] ERROR: $*" >&2
  exit 1
}

install_public_ssh_key() {
  if [[ -z "${TEAM_PUBLIC_KEY}" ]]; then
    log "TEAM_PUBLIC_KEY not set; direct SSH may require manual authorized_keys setup"
    return
  fi

  touch /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys || true
  if grep -Fxq "${TEAM_PUBLIC_KEY}" /root/.ssh/authorized_keys; then
    log "TEAM_PUBLIC_KEY already exists in authorized_keys"
  else
    printf '%s\n' "${TEAM_PUBLIC_KEY}" >> /root/.ssh/authorized_keys
    log "Added TEAM_PUBLIC_KEY to authorized_keys"
  fi
}

start_sshd() {
  if pgrep -x sshd >/dev/null 2>&1; then
    log "sshd already running"
  else
    /usr/sbin/sshd
    log "sshd started"
  fi
}

write_private_key() {
  local env_name="$1"
  local key_b64="$2"
  local key_path="$3"

  if [[ -z "${key_b64}" ]]; then
    fail "${env_name} is required for team workspace bootstrap"
  fi

  printf '%s' "${key_b64}" | tr -d '\r\n ' | base64 -d > "${key_path}" || fail "failed to decode ${env_name}"
  chmod 600 "${key_path}"
}

configure_github_ssh() {
  local navy_key="/root/.ssh/github_navy_ai"
  local preprocessing_key="/root/.ssh/github_navy_ai_preprocessing"

  write_private_key "GITHUB_NAVY_AI_DEPLOY_KEY_B64" "${NAVY_AI_KEY_B64}" "${navy_key}"
  write_private_key "GITHUB_PREPROCESSING_DEPLOY_KEY_B64" "${PREPROCESSING_KEY_B64}" "${preprocessing_key}"

  ssh-keyscan github.com >> /root/.ssh/known_hosts 2>/dev/null || true
  sort -u /root/.ssh/known_hosts -o /root/.ssh/known_hosts 2>/dev/null || true
  chmod 644 /root/.ssh/known_hosts || true

  cat > /root/.ssh/config <<EOF
Host github.com-navy-ai
  HostName github.com
  User git
  IdentityFile ${navy_key}
  IdentitiesOnly yes

Host github.com-navy-ai-preprocessing
  HostName github.com
  User git
  IdentityFile ${preprocessing_key}
  IdentitiesOnly yes
EOF
  chmod 600 /root/.ssh/config
}

login_wandb() {
  if ! command -v wandb >/dev/null 2>&1; then
    log "wandb CLI not found"
    return
  fi
  if [[ -n "${WANDB_API_KEY:-}" ]]; then
    wandb login --relogin "${WANDB_API_KEY}" || log "W&B login failed"
  else
    log "WANDB_API_KEY not set; run 'wandb login' later if needed"
  fi
}

clone_or_update() {
  local repo_url="$1"
  local target_dir="$2"
  local user_name="${3:-}"
  local user_email="${4:-}"

  if [[ -d "${target_dir}/.git" ]]; then
    log "repo exists: ${target_dir}"
    git -C "${target_dir}" fetch --all --prune || {
      log "fetch failed: ${target_dir}"
      return
    }
    if [[ "${TEAM_BOOTSTRAP_PULL}" == "always" ]]; then
      git -C "${target_dir}" pull --ff-only || log "pull failed: ${target_dir}"
    elif [[ "${TEAM_BOOTSTRAP_PULL}" == "safe" ]]; then
      if [[ -z "$(git -C "${target_dir}" status --short)" ]]; then
        git -C "${target_dir}" pull --ff-only || log "pull failed: ${target_dir}"
      else
        log "dirty worktree; fetched but skipped pull: ${target_dir}"
      fi
    else
      log "TEAM_BOOTSTRAP_PULL=${TEAM_BOOTSTRAP_PULL}; fetched but skipped pull: ${target_dir}"
    fi
  else
    log "cloning ${repo_url} -> ${target_dir}"
    mkdir -p "$(dirname "${target_dir}")"
    git clone "${repo_url}" "${target_dir}" || {
      log "clone failed: ${target_dir}"
      return
    }
  fi

  if [[ -n "${user_name}" ]]; then
    git -C "${target_dir}" config user.name "${user_name}"
  fi
  if [[ -n "${user_email}" ]]; then
    git -C "${target_dir}" config user.email "${user_email}"
  fi
}

bootstrap_team_workspace() {
  mkdir -p "${WORKSPACE_ROOT}" "${DATA_DIR}"

  clone_or_update "${NAVY_AI_REPO}" "${WORKSPACE_ROOT}/hothyun/navy-ai" "HotHyun" "ohsong656565@gmail.com"
  clone_or_update "${NAVY_AI_REPO}" "${WORKSPACE_ROOT}/seayurre/navy-ai" "seayurre" "yulyul03@daum.net"
  clone_or_update "${NAVY_AI_REPO}" "${WORKSPACE_ROOT}/ybuser/navy-ai" "ybuser" "ybuser@naver.com"
  clone_or_update "${NAVY_AI_REPO}" "${WORKSPACE_ROOT}/k0ykwon/navy-ai" "K0ykwon" "yko081524@yonsei.ac.kr"
  clone_or_update "${PREPROCESSING_REPO}" "${PREPROCESSING_DIR}"

  cat <<EOF

[gpu-startup] Team workspace ready:
  ${WORKSPACE_ROOT}/hothyun/navy-ai
  ${WORKSPACE_ROOT}/seayurre/navy-ai
  ${WORKSPACE_ROOT}/ybuser/navy-ai
  ${WORKSPACE_ROOT}/k0ykwon/navy-ai
  ${DATA_DIR}
  ${PREPROCESSING_DIR}
EOF
}

main() {
  mkdir -p /run/sshd /root/.ssh "${WORKSPACE_ROOT}"
  chmod 700 /root/.ssh || true

  install_public_ssh_key
  start_sshd
  configure_github_ssh
  login_wandb
  bootstrap_team_workspace

  log "Ready. Keeping container alive."
  tail -f /dev/null
}

main "$@"
