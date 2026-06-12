#!/bin/bash
# Buildkite agent wrapper for the seatbelt-sandboxed macOS Metal agents.
#
# Launched at boot by a LaunchDaemon running as the unprivileged `julia` user
# (see org.juliagpu.buildkite.monoceros.1.plist). Gives each job a fresh
# environment, analogous to the fresh container per job on the Linux agents:
# scratch dirs (HOME, TMPDIR, build dir) are wiped between jobs, and the
# agent runs with --disconnect-after-job inside the seatbelt sandbox.
set -u

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_NAME="$(basename "${AGENT_DIR}")"

USER_HOME="/Users/julia"
SCRATCH="${USER_HOME}/scratch"   # wiped between jobs
CACHE="${USER_HOME}/cache"       # persistent (git mirrors); build dir wiped
SECRETS="${USER_HOME}/secrets"   # token.env + secrets.private.key, mode 700

# launchd daemons get a minimal environment; set up our own. The brew
# openssl comes first so the secrets hook doesn't use the system LibreSSL.
export PATH="/opt/homebrew/opt/openssl@3/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
source "${SECRETS}/token.env"
export BUILDKITE_AGENT_TOKEN

# e.g. "Apple M1 Pro" -> "m1_pro"
GPU="$(sysctl -n machdep.cpu.brand_string | sed 's/^Apple //' | tr 'A-Z ' 'a-z_')"

# macOS doesn't like services restarting all the time, so keep launching
# agents until we're asked to quit.
while true; do
    # Give the job a pristine environment
    chmod -R u+w "${SCRATCH}" "${CACHE}/build" 2>/dev/null
    rm -rf "${SCRATCH}" "${CACHE}/build"
    mkdir -p "${SCRATCH}/home" "${SCRATCH}/tmp" "${CACHE}/build" "${CACHE}/repos"

    # Also wipe this user's per-user cache/temp dirs (Metal shader cache,
    # etc.), which live under /private/var/folders and are writable from
    # within the sandbox.
    for dir in "$(getconf DARWIN_USER_CACHE_DIR)" "$(getconf DARWIN_USER_TEMP_DIR)"; do
        rm -rf "${dir:?}"/* 2>/dev/null
    done

    # Copy the secrets decryption key into the job environment; the
    # environment hook deletes it again after decrypting any secrets.
    export BUILDKITE_SECRETS_KEY="${SCRATCH}/home/secrets.private.key"
    cp "${SECRETS}/secrets.private.key" "${BUILDKITE_SECRETS_KEY}"

    HOME="${SCRATCH}/home" TMPDIR="${SCRATCH}/tmp" \
    sandbox-exec -f "${AGENT_DIR}/sandbox.sb" \
        buildkite-agent start \
            --disconnect-after-job \
            --hooks-path="${AGENT_DIR}/hooks" \
            --build-path="${CACHE}/build" \
            --git-mirrors-path="${CACHE}/repos" \
            --tags="queue=metal,arch=aarch64,gpu=${GPU},macos_version=$(sw_vers -productVersion)" \
            --name="${AGENT_NAME}"
    ret=$?
    echo "Agent exited with status ${ret}"

    # An exit code of 255 indicates graceful termination (e.g. agent
    # stopped from the Buildkite UI); stop the service in that case.
    if [[ ${ret} -eq 255 ]]; then
        echo "Stopping service after graceful termination"
        break
    fi
done

# Clean up and return success, so that launchd does not restart us
# (KeepAlive.SuccessfulExit = false)
rm -rf "${SCRATCH}"
exit 0
