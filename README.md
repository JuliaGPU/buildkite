# JuliaGPU Buildkite

## Adding an agent

First, create a `docker-compose.yml` suitable for this host. The current approach is to
spawn a single agent per GPU, limiting total parallelism (sum of all `JULIA_NUM_THREADS`
values) to a reasonable number for this system (each CUDA context takes a couple of 100s of
MBs, realistic test suites easily consume multiple GBs of VRAM, and each Julia process also
consumes multiple GBs of system memory).

On the agent host, clone this repository and add a `token.env` to the root:

```
# git clone https://github.com/maleadt/buildkite-agents /opt/buildkite-agents
```

Make sure a recent version of `docker-compose` is available:

```
# curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
```

If running GPU jobs, make sure the [NVIDIA container
runtime](https://github.com/NVIDIA/nvidia-container-runtime) is installed. Note that the
latest docker-compose does not support the new `--gpus` flag yet, so `docker --runtime
nvidia` still needs to work. You can hack this by adding the following to
`/etc/docker/daemon.json`:

```json
{
    "runtimes": {
        "nvidia": {
            "path": "/usr/bin/nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
```

Install the `docker-compose` systemd unit, if none is available:

```
# cp docker-compose@.service /etc/systemd/system/
```

Install the `docker-compose` template according to the systemd service:

```
# mkdir -p /etc/docker/compose
# ln -s /opt/buildkite-agents/HOSTNAME /etc/docker/compose/buildkite-agent
```

Finally, enable and start the buildkite agent:

```
# systemctl enable --now docker-compose@buildkite-agent
```
