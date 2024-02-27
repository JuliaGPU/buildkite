ARG base=ubuntu:latest
FROM $base

# install dependencies for Buildkite and its plugins
# (notably julia-buildkite-plugin and cryptic-buildkite-plugin)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      curl wget apt-transport-https gnupg2 python3 python3-pip openssl jq && \
    pip install --no-cache-dir shyaml

RUN wget -O- https://keys.openpgp.org/vks/v1/by-fingerprint/32A37959C2FA5C3C99EFBC32A79206696452D198 > \
      /tmp/buildkite-agent-archive-keyring.gpg && \
    bash -c "cat /tmp/buildkite-agent-archive-keyring.gpg | \
      gpg --dearmor > /usr/share/keyrings/buildkite-agent-archive-keyring.gpg" && \
    echo "deb [signed-by=/usr/share/keyrings/buildkite-agent-archive-keyring.gpg] https://apt.buildkite.com/buildkite-agent stable main" > \
      /etc/apt/sources.list.d/buildkite-agent.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y buildkite-agent

RUN rm -rf /var/lib/apt/lists/*

COPY agent.pub agent.key /secrets/

COPY hooks /hooks

ENTRYPOINT ["buildkite-agent"]
CMD ["start"]
