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


## Providing secrets

During start-up, agents will scan for `SECRET_` environment variables and decrypt their
contents for use in the rest of the pipeline. If you want to use this mechanism to provide,
say, a secret `CODECOV_TOKEN`, run the following command using the public key that is part
of this repository:

```
$ echo TOKEN_VALUE | openssl rsautl -encrypt -pubin -inkey secrets.public.key | openssl base64
mOVpzB+EekkilXKIhaDv+iB4/s+OhFd4iGQdfivDBXKqxQ+hMYED0ic12H1CeAD2
iaJytYOhDk5Cx6eVLPSypmcXH0+8BwPzLsxmPpgCq2qRdrzC9X6IjP6d5AnfERjm
qZyjCBnz11sM45t4hGABZRzblqqyMaHss9EZrg7ztkvLtWeqLI4GIcQCdFUW6ooV
k/XfVzt3IK36iEfErowrTWEFfZ1jskRXO91naCURPpPvM1bdEEXo+CdZhUa6XxWQ
+AvCEIgZQywth1PT1faRSxj6ouACJPr21mQpniVtoBvDm0BpUUNHdwibt4Cm6WqY
95FzR8931CalRiCKYWjhxA==
```

You can now join and put this value in the global environment of your `pipeline.yml`,
prepending the target environment variable with `SECRET_`:

```yaml
env:
  SECRET_CODECOV_TOKEN: "mOVpzB+EekkilXKIhaDv+iB4/s+OhFd4iGQdfivDBXKqxQ+hMYED0ic12H1CeAD2iaJytYOhDk5Cx6eVLPSypmcXH0+8BwPzLsxmPpgCq2qRdrzC9X6IjP6d5AnfERjmqZyjCBnz11sM45t4hGABZRzblqqyMaHss9EZrg7ztkvLtWeqLI4GIcQCdFUW6ooVk/XfVzt3IK36iEfErowrTWEFfZ1jskRXO91naCURPpPvM1bdEEXo+CdZhUa6XxWQ+AvCEIgZQywth1PT1faRSxj6ouACJPr21mQpniVtoBvDm0BpUUNHdwibt4Cm6WqY95FzR8931CalRiCKYWjhxA=="
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
