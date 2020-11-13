# JuliaGPU Buildkite

This repository contains resources related to the JuliaGPU Buildkite CI infrastructure:

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

This README documents how to use the JuliaGPU Buildkite CI. For details on the available
agents, or how to add one, see the [agents README](agents/README.md). **Note that this
Buildkite set-up is fairly new, and the set-up may still change. Keep an eye on this README
if anything breaks.**


## Adding a repository

If your Julia package can use a GPU, you may use the JuliaGPU CI infrastructure to run tests
on a system with a GPU. This is **not a general-purpose CI service**, and only intended to
run GPU-related tests of Julia packages. For all other testing, use public infrastructure
(Travis, Github Actions, etc).

Some of the steps below require administrative privileges on the JuliaLang Buildkite
instance, so you should coordinate on e.g. the JuliaGPU Slack channel or Discourse category.

0. Install [the Buildkite
   app](https://github.com/settings/connections/applications/Iv1.112bf4be3e5ecdeb). You
   should check on the link whether the app is already installed for the GitHub organization
   that hosts your repository. If it isn't, a Buildkite administrator needs to [request
   installation of the
   app](https://buildkite.com/organizations/julialang/repository-providers/new), for which
   he needs to be part of the GitHub organization. The request then needs to be accepted by
   an owner of the GitHub organization (organization settings > installed GitHub Apps >
   Pending GitHub Apps installation requests).

1. (by a Buildkite admin) [Create a new
   pipeline](https://buildkite.com/organizations/julialang/pipelines/new), using the
   package's name.

   a. Under `Git Repository`, select `Any account` and specify the package's HTTPS clone
      URL, e.g. `https://github.com/JuliaGPU/CUDA.jl.git`. Do not use the `git://` URL!

   b. Remove the default step.

   c. Grant permission to the JuliaGPU team.

2. Apply the proposed GitHub webhook settings to your repository.

3. (by a Buildkite admin) Navigate to the Pipeline Settings.

   a. Under general settings, make the pipeline public by clicking the big green button.

   b. Under GitHub settings, check the box to `Build pull requests from third-party forked
      repositories` and to `Build tags`.

3. (by a Buildkite admin) Edit the pipeline steps.

   a. Convert to YAML.

   b. Paste the following step to upload a pipeline from the repository:

   ```yaml
   steps:
     - label: ":buildkite: Pipeline upload"
       command: buildkite-agent pipeline upload
       branches: "!gh-pages"
       agents:
         queue: "juliagpu"
   ```

4. In your repository, create `.buildkite/pipeline.yml`. Use this as a starting point:

   ```yaml
   env:
     SECRET_CODECOV_TOKEN: "..."

   steps:
     - label: "Julia 1.5"
       plugins:
         - JuliaCI/julia#v0.2:
             version: 1.5
         - JuliaCI/julia-test#v0.2: ~
         - JuliaCI/julia-coverage#v0.2:
             codecov: true
       agents:
         queue: "juliagpu"
         cuda: "*"
   ```

    If you want to perform several tests, or introduce test phases, you may want to add
    additional steps. Note that each step is run in a fresh container (as opposed to how
    Buildkite normally works), so you need to repeat the set-up that provides Julia (here
    done by the `julia` plugin) and/or instantiates your project (done by the `julia-test`
    plugin). If you need to send resources across steps, use
    [artifacts](https://buildkite.com/docs/pipelines/artifacts).

    For coverage submission to Codecov to work, you need to encrypt your `CODECOV_TOKEN` and
    specify it as a global `SECRET_CODECOV_TOKEN` (see below).



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
