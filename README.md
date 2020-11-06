# JuliaGPU Buildkite

This repository contains resources related to the JuliaGPU Buildkite agents.
There are several important differences from the upstream Buildkite agent image:

- a custom Ubuntu-based image that can be based off of another image (e.g.
  CUDA's images);
- support for encrypted environment variables in the pipeline, and an
  environment hook to decode them;
- Docker Compose templates and systemd service files to tie everything together,
  and give each job a safe and reproducible execution environment.

Many of these features come from the fact that the JuliaGPU CI is intended to be
run on a variety of repositories (and external PRs to those repositories),
whereas Buildkite is typically used within the (trusted) boundaries of a single
organization.


## Using secrets

During start-up, agents will scan for `SECRET_` environment variables and decrypt their
contents for use in the rest of the pipeline. If you want to use this mechanism to provide,
say, a secret `CODECOV_TOKEN`, run the `encrypt` script in this repository and follow its
prompts:


```
$ ./tools/encrypt
Variable name: CODECOV_TOKEN
Secret value:

Use the following snippet in your pipeline.yml:

env:
    SECRET_CODECOV_TOKEN: "kaIXEN51HinaQ4JGclQcIgxeMMtXDb5uvnP3E2eKrH4Eruf2pKd5QwUGcIVL8+rcWeo5FWj883rNxRQEH3YeCWs6/i7vzs+ORvG51QeCNYQgNqFzPsWRcq5qJYc+JPFbisS7q9nghqWTwr52cnjarD4Xx3ceGorMyS5NvFpCNxMgqHNyGkLvipxcTTJfKZK61bpnbntoIjiIO1XSZKjcxnXFGFnolV9BHCr5v8f7F42n2tUH7X3nDHmTBr1AbO2lFAU9ra/KezHcIf0wg2HcV8LZD0+mj8q/SBPjQZSH7cxwx4Q2eTjT4Sw7xnrBGuySVm8ZPCAV7nRNEHo+VqR+GQ=="
```


## Adding an agent

First, create a Docker Compose YAML template suitable for this agent. The
current approach is to create an agent per GPU, limiting total parallelism (sum
of all `JULIA_NUM_THREADS` values) to a reasonable number for this system (each
CUDA context takes a couple of 100s of MBs, realistic test suites easily consume
multiple GBs of VRAM, and each Julia process also consumes multiple GBs of
system memory).

On the agent host, clone this repository and add an appropriate `token.env` and
`secrets.private.key`(these files are not part of the repository for obvious reasons):

```
# git clone https://github.com/maleadt/buildkite-agents /etc/buildkite
# ...
# chown root:root agents/token.env image/secrets.private.key
# chmod 600       agents/token.env image/secrets.private.key
```

Make sure a recent version of `docker-compose` is available:

```
# curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
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
```

Finally, enable and start the buildkite agents:

```
# systemctl enable --now buildkite-agent@AGENT
# ...
```
