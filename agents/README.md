# Available agents

All JuliaGPU agents are put under the `juliagpu` queue, so you should always include the
`queue: "juliagpu"` line in the `agents` block of your steps. Then, you should select which
kind of GPU runner you are interested in.

## `cuda`

These agents have one or more CUDA GPUs available, and can be used with CUDA.jl. The value
of the `cuda` label indicates which CUDA version is supported by the driver on this agent,
in case you need a specific CUDA version. If not, specify `cuda: "*"` to select any
CUDA-capable agent.

Similarly, these agents have a `cap` label to select on device capability, e.g. `sm_75`. A
shorthand `cap: "recent"` can be used to select a range of GPUs with a recent-enough compute
capability.

Finally, if you need multiple GPUs for your tests you can request the `multigpu` label, and
for tests that need an X server there is the `xorg` label. Few agents have these label, so
don't do so needlessly.

## `intel`

These agents have an oneAPI-capable GPU for use with oneAPI.jl. The value of the `intel` tag
indicates the hardware generation, e.g. `gen9`.

## `rocm`

These agents have one AMD GPU for use with AMDGPU.jl. Most necessary ROCm external libraries
are installed and available. Image is based on `rocm/dev-ubuntu-20.04`.


# Adding an agent

First, create a Docker Compose YAML template suitable for this agent. The
current approach is to create an agent per GPU, limiting total parallelism (sum
of all `JULIA_CPU_THREADS` values) to a reasonable number for this system (each
CUDA context takes a couple of 100s of MBs, realistic test suites easily consume
multiple GBs of VRAM, and each Julia process also consumes multiple GBs of
system memory).

On the agent host, clone this repository and add an appropriate `token.env` and
`agent.pub`/`agent.key` keys to respectively the `agents` and `image` directories
(these files are not part of the repository for obvious reasons):

```
# git clone https://github.com/JuliaGPU/buildkite /etc/buildkite
# ...
# chown root:root agents/token.env image/agent.pub image/agent.key
# chmod 600       agents/token.env image/agent.pub image/agent.key
```

Make sure a recent version of `docker-compose` is available:

```
# curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
# chmod +x /usr/local/bin/docker-compose
```

If running GPU jobs, make sure the [NVIDIA container
runtime](https://github.com/NVIDIA/nvidia-container-runtime) is installed. Note
that the latest docker-compose does not support the new `--gpus` flag yet, so
`docker --runtime nvidia` still needs to work. You can hack this by adding the
following to `/etc/docker/daemon.json`:

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

Install the `buildkite-agent` systemd unit:

```
# ln -s /etc/buildkite/buildkite-agent@.service /etc/systemd/system/
# systemctl daemon-reload
```

Finally, enable and start the buildkite agents:

```
# systemctl enable --now buildkite-agent@AGENT
# ...
```
