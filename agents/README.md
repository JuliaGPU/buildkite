# Available agents

All JuliaGPU agents are part of the [JuliaGPU
cluster](https://buildkite.com/organizations/julialang/clusters/b20f6e32-1a01-4a61-adf4-ff393b684836/queues),
and are registered with a queue that indicates the kind of GPU runner, e.g., `queue: "cuda"`
in the `agents` block of your steps. Additional labels can be used to select specific
hardware.

## `cuda`

These agents have one or more CUDA GPUs available, and can be used with CUDA.jl.

These agents have a `cap` label to select on device capability, e.g. `sm_75`. A
shorthand `cap: "recent"` can be used to select a range of GPUs with a recent-enough compute
capability.

If you need multiple GPUs for your tests you can request the `multigpu` label, and
for tests that need an X server there is the `xorg` label. Few agents have these label, so
don't do so needlessly.

Agents intended for benchmarking carry the `benchmark` label and run at the lowest
priority, so that regular CI jobs prefer the other agents. Conversely, benchmark jobs
should request `benchmark: "true"` to land on these agents.

## `oneapi`

These agents have an oneAPI-capable GPU for use with oneAPI.jl.

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
`secrets.private.key`(these files are not part of the repository for obvious reasons):

```
# git clone https://github.com/JuliaGPU/buildkite /etc/buildkite
# ...
# chown root:root agents/token.env image/secrets.private.key
# chmod 600       agents/token.env image/secrets.private.key
```

If running GPU jobs, make sure the [NVIDIA container
runtime](https://github.com/NVIDIA/nvidia-container-runtime) is installed.

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
