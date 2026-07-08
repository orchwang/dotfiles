# offline-devkit builder image — deliberately BARE.
#
# CRITICAL: this must stay a clean `ubuntu:24.04` with nothing extra installed.
# build-in-container.sh harvests the target's .deb dependency closure with
# `apt-get -d install` against this base BEFORE installing any tooling. If we
# pre-installed curl/git/build-essential here, their shared-library deps
# (libbrotli1, libcurl4, krb5, ...) would already be present at harvest time and
# would be EXCLUDED from the closure — then miss on the target, where e.g. node
# fails with "libbrotlidec.so.1: cannot open shared object file".
#
# So: no `apt-get install` here. The download tooling (curl, git, xz-utils) is
# installed at runtime by build-in-container.sh, AFTER the closure is captured.
ARG BASE=ubuntu:24.04
FROM ${BASE}

ENV DEBIAN_FRONTEND=noninteractive

# The repo is bind-mounted read-only at /repo and the output dir writable at
# /out by build.sh; the builder script is invoked from there at run time.
WORKDIR /repo
ENTRYPOINT ["/bin/bash"]
