ARG RUBY_VERSION=3.4.12
FROM ruby:${RUBY_VERSION}

LABEL maintainer="security-research"
LABEL description="Ruby2Shell reproduction environment"

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    valgrind \
    gdb \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install pwndbg for heap analysis
RUN git clone --depth=1 https://github.com/pwndbg/pwndbg /opt/pwndbg \
    && cd /opt/pwndbg \
    && ./setup.sh || true

WORKDIR /work

CMD ["bash"]
