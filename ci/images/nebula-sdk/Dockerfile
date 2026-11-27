FROM python:3.13-slim-trixie@sha256:7249d5587b78209a006dc4a3b5340678f84ea729239193aa559962cd8c1fce50 AS python_runtime
FROM dart:3.12.0@sha256:1bc3667e7e5d647bf0f00d62673790b06719ba39e108776a7cc3529887e81fb7
COPY --from=python_runtime /usr/local /usr/local
ENV PUB_CACHE=/opt/nebula-pub-cache
COPY cache/ /opt/nebula-pub-cache/
RUN mkdir -p /opt && printf '%s\n' 'nebula-sdk-ci-candidate-20261127-v1' > /opt/nebula-sdk-ci-id && python3 -c 'import os,json,re,hashlib' && dart --version
WORKDIR /workspace
