# ---------- builder ----------
FROM ubuntu:24.04 AS build

ARG DEBIAN_FRONTEND=noninteractive
ARG OQS_REF=main
ARG OQS_PY_REF=main

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git ca-certificates \
    python3 python3-pip python3-venv python3-dev \
    libffi-dev pkg-config \
 && rm -rf /var/lib/apt/lists/*

# Build liboqs
WORKDIR /src
RUN git clone --depth 1 --branch ${OQS_REF} https://github.com/open-quantum-safe/liboqs.git
WORKDIR /src/liboqs/build
RUN cmake -DCMAKE_BUILD_TYPE=Release \
          -DOQS_USE_OPENSSL=OFF \
          -DBUILD_SHARED_LIBS=ON \
          -DCMAKE_INSTALL_PREFIX=/opt/liboqs ..
RUN make -j"$(nproc)" && make install

# Build a venv with liboqs-python
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV \
 && $VIRTUAL_ENV/bin/pip install --upgrade pip \
 && OQS_INCLUDE_DIR=/opt/liboqs/include \
    OQS_LIBRARY_DIR=/opt/liboqs/lib \
    $VIRTUAL_ENV/bin/pip install --no-cache-dir "git+https://github.com/open-quantum-safe/liboqs-python@${OQS_PY_REF}" \
 && $VIRTUAL_ENV/bin/pip install --no-cache-dir pyRAPL matplotlib pandas \
 && $VIRTUAL_ENV/bin/python -m compileall -q $VIRTUAL_ENV

# ---------- runtime ----------
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 libffi8 \
 && rm -rf /var/lib/apt/lists/*

# Bring in artifacts
COPY --from=build /opt/liboqs /opt/liboqs
COPY --from=build /opt/venv /opt/venv

# Dynamic linker config
RUN echo "/opt/liboqs/lib" > /etc/ld.so.conf.d/liboqs.conf && ldconfig

# Helpful envs
ENV OQS_LIB=/opt/liboqs/lib/liboqs.so
ENV OQS_LIB_DIR=/opt/liboqs/lib
ENV LD_LIBRARY_PATH=/opt/liboqs/lib
ENV LIBRARY_PATH=/opt/liboqs/lib
ENV C_INCLUDE_PATH=/opt/liboqs/include
ENV PATH=/opt/venv/bin:$PATH

WORKDIR /app
COPY kyber_test.py /app/kyber_test.py
CMD ["python3", "/app/kyber_test.py"]

