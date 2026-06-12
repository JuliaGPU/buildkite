# macOS Metal agents

Unlike the Linux agents, which use Docker for isolation, macOS agents run the
buildkite-agent inside an Apple Seatbelt sandbox (`sandbox-exec`), which
provides kernel-enforced containment while keeping native access to the GPU
(containers and VMs would only offer no or paravirtualized Metal,
respectively). The moving parts:

- `sandbox.sb`: static seatbelt profile. Jobs can read the system, and can
  only write to the scratch/cache directories. No access to user data.
- `wrapper.sh`: runs the agent in a loop with `--disconnect-after-job`,
  wiping scratch directories between jobs (the equivalent of a fresh
  container per job on the Linux agents).
- `org.juliagpu.buildkite.monoceros.1.plist`: LaunchDaemon definition, starting
  the wrapper at boot (no login session required) as the unprivileged
  `julia` user.
- `hooks/environment`: macOS-adapted version of `image/hooks/environment`
  for secrets decryption.

## Host setup

One-time setup, as an administrator. FileVault must be disabled for the
machine to boot unattended.

```sh
# dependencies
brew install buildkite-agent openssl@3

# unprivileged CI user (no password; use `sudo su julia` from an admin
# account; no sudo/admin rights needed)
sudo sysadminctl -addUser julia -fullName "JuliaGPU CI" -home /Users/julia
sudo createhomedir -c -u julia

# this repository; root-owned so that the CI user cannot modify its own
# sandbox definition
sudo git clone https://github.com/JuliaGPU/buildkite /Users/julia/juliagpu-buildkite

# secrets, only readable by the julia user
sudo -u julia mkdir -m 700 /Users/julia/secrets
# ... copy agents/token.env and image/secrets.private.key into it ...
sudo chown julia /Users/julia/secrets/*
sudo chmod 600 /Users/julia/secrets/*

# the agent service
sudo cp /Users/julia/juliagpu-buildkite/agents/monoceros.1/org.juliagpu.buildkite.monoceros.1.plist /Library/LaunchDaemons/
sudo chown root:wheel /Library/LaunchDaemons/org.juliagpu.buildkite.monoceros.1.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/org.juliagpu.buildkite.monoceros.1.plist

# come back up after power loss; never sleep
sudo pmset autorestart 1 sleep 0 disksleep 0
```

To update the agent configuration, `sudo git pull` in
/Users/julia/juliagpu-buildkite and restart
the service:

```sh
sudo launchctl kickstart -k system/org.juliagpu.buildkite.monoceros.1
```

Logs end up in `/Users/julia/agent.log`.
