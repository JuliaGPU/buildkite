ARG base=ubuntu:latest
FROM $base

RUN apt-get update && \
    apt-get install -y curl wget apt-transport-https openssl gnupg2 python3 texlive-full liblapack3

RUN echo 'deb https://apt.buildkite.com/buildkite-agent stable main' >> /etc/apt/sources.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 32A37959C2FA5C3C99EFBC32A79206696452D198 && \
    apt-get update && \
    apt-get install -y buildkite-agent

COPY secrets.private.key /
COPY hooks /hooks

ENTRYPOINT ["buildkite-agent"]
CMD ["start"]
