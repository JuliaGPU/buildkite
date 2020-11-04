ARG base=nvidia/cuda
FROM $base

RUN apt-get update && \
    apt-get install -y curl apt-transport-https

RUN echo 'deb https://apt.buildkite.com/buildkite-agent stable main' >> /etc/apt/sources.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 32A37959C2FA5C3C99EFBC32A79206696452D198 && \
    apt-get update && \
    apt-get install -y buildkite-agent

ENTRYPOINT ["buildkite-agent"]
CMD ["start"]
