# One image for EVERY pod — Spark master, workers, the Spark Connect server and
# Jupyter. PySpark refuses to run when the driver and executors use different
# Python minor versions, so they must all share this exact interpreter.
#
# Don't edit the versions or packages here: set `versions:` and `extraPackages:`
# in charts/spark/values.yaml (or your own -f overrides file). spinup.sh reads
# them and Skaffold passes them in as these build args. The defaults below only
# apply to a bare `docker build`.
ARG SPARK_VERSION=4.1.0
ARG JAVA_VERSION=17

# Stock Apache Spark distribution, *without* the bundled Python — we bring our own.
FROM apache/spark:${SPARK_VERSION}-scala2.13-java${JAVA_VERSION}-ubuntu

ARG SPARK_VERSION
ARG PYTHON_VERSION=3.12
ARG DELTA_SPARK_VERSION=4.2.0
# Extra Maven coordinates (comma-separated, like spark --packages) and pip specs
# (space-separated, like pip install). Baked into every pod: driver AND executors.
ARG EXTRA_MAVEN_PACKAGES=""
ARG EXTRA_PIP_PACKAGES=""
# protobuf-java required by the Delta Connect server plugin (see below).
ARG DELTA_CONNECT_PROTOBUF=3.25.1

USER root

# --- Python ${PYTHON_VERSION} (any CPython version, via uv's standalone builds) --
COPY --from=ghcr.io/astral-sh/uv:0.9.5 /uv /usr/local/bin/uv
ENV UV_PYTHON_INSTALL_DIR=/opt/python \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:/opt/spark/bin:/opt/spark/sbin:${PATH}
RUN set -eux; \
    uv venv --python "${PYTHON_VERSION}" /opt/venv; \
    ln -sf /opt/venv/bin/python /usr/local/bin/python3; \
    ln -sf /opt/venv/bin/python /usr/local/bin/python; \
    # PySpark + Spark Connect client runtime deps, JupyterLab, and the delta-spark
    # Python API (--no-deps: PySpark itself comes from /opt/spark/python below,
    # so it always matches the cluster's Spark exactly).
    uv pip install --no-cache jupyterlab pandas pyarrow numpy \
        grpcio grpcio-status googleapis-common-protos zstandard; \
    uv pip install --no-cache --no-deps "delta-spark==${DELTA_SPARK_VERSION}"; \
    if [ -n "${EXTRA_PIP_PACKAGES}" ]; then uv pip install --no-cache ${EXTRA_PIP_PACKAGES}; fi; \
    # Make the distribution's own PySpark + py4j importable (no version hardcoding).
    site="$(python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"; \
    { echo /opt/spark/python; ls /opt/spark/python/lib/py4j-*-src.zip; } > "${site}/pyspark-dist.pth"; \
    python -c "import pyspark, delta; print('pyspark', pyspark.__version__)"

# --- Delta Lake (+ Delta Connect) and extra jars, baked into Spark's classpath --
# Delta >= 4.1 publishes one artifact per Spark minor (delta-spark_4.1_2.13);
# older releases use delta-spark_2.13. Resolve everything with Spark's own Ivy,
# then copy only the jars Spark doesn't already ship so Spark's versions win.
# The Delta Connect server plugin is optional (skipped if not published for this
# Delta release); the chart turns it on with connect.deltaConnect.
RUN set -eux; \
    mm="${SPARK_VERSION%.*}"; \
    delta_artifact() { \
      for a in "$1_${mm}_2.13" "$1_2.13"; do \
        if curl -fsI "https://repo1.maven.org/maven2/io/delta/${a}/${DELTA_SPARK_VERSION}/" >/dev/null; then \
          echo "io.delta:${a}:${DELTA_SPARK_VERSION}"; return; \
        fi; \
      done; \
    }; \
    packages="$(delta_artifact delta-spark)"; \
    [ -n "${packages}" ] || { echo "Delta ${DELTA_SPARK_VERSION} is not published for Spark ${mm}"; exit 1; }; \
    connect="$(delta_artifact delta-connect-server)"; \
    # Delta Connect's generated code needs unshaded protobuf-java >= 3.25 (Spark
    # only ships shaded copies, and Delta's pom asks for 3.24.4, which lacks
    # MapFieldReflectionAccessor). Ivy keeps the newer version on conflict.
    if [ -n "${connect}" ]; then packages="${packages},${connect},com.google.protobuf:protobuf-java:${DELTA_CONNECT_PROTOBUF}"; \
    else echo "NOTE: no Delta Connect server for Delta ${DELTA_SPARK_VERSION}"; fi; \
    if [ -n "${EXTRA_MAVEN_PACKAGES}" ]; then packages="${packages},${EXTRA_MAVEN_PACKAGES}"; fi; \
    spark-submit --master 'local[1]' --conf spark.jars.ivy=/tmp/ivy --packages "${packages}" \
      --class org.apache.spark.examples.SparkPi /opt/spark/examples/jars/spark-examples_*.jar 1 \
      > /tmp/resolve.log 2>&1 && grep -q 'Pi is roughly' /tmp/resolve.log \
      || { grep -iE 'not found|unresolved|error' /tmp/resolve.log | head -20; \
           echo "Could not resolve: ${packages}"; exit 1; }; \
    for jar in /tmp/ivy/jars/*.jar; do \
      name="$(basename "$jar" .jar)"; name="${name#*_}"; \
      name="$(echo "$name" | sed -E 's/-[0-9][^-]*(-.*)?$//')"; \
      ls /opt/spark/jars | grep -q "^${name}-[0-9]" || cp "$jar" /opt/spark/jars/; \
    done; \
    rm -rf /tmp/ivy /root/.ivy2* /tmp/resolve.log; \
    ls /opt/spark/jars | grep -i delta; \
    # delta-spark (pip) pins a PySpark range; warn — don't fail — when outside it,
    # since the jar above is matched to the Spark minor already.
    python -c "from importlib.metadata import requires; from packaging.requirements import Requirement; \
spec = next((r.specifier for r in map(Requirement, requires('delta-spark') or []) if r.name == 'pyspark'), None); \
spec is None or spec.contains('${SPARK_VERSION}', prereleases=True) or \
print('WARNING: delta-spark ${DELTA_SPARK_VERSION} supports pyspark' + str(spec) + ', cluster is Spark ${SPARK_VERSION}')"

# Cluster-wide Spark defaults, shared by every app (Jupyter, Spark Connect, spark-submit):
# - Delta enabled out of the box.
# - Dynamic allocation: apps release idle executors after 60s, so a Jupyter session
#   and the always-on Spark Connect server share the workers without starving each
#   other. The worker's external shuffle service keeps shuffle files alive after an
#   executor is released (the worker reads this same file and starts the service).
RUN set -eux; \
    mkdir -p /opt/spark/conf /opt/spark/work-dir /home/spark; \
    printf '%s\n' \
      'spark.sql.extensions                              io.delta.sql.DeltaSparkSessionExtension' \
      'spark.sql.catalog.spark_catalog                   org.apache.spark.sql.delta.catalog.DeltaCatalog' \
      'spark.executor.cores                              1' \
      'spark.executor.memory                             1g' \
      'spark.dynamicAllocation.enabled                   true' \
      'spark.shuffle.service.enabled                     true' \
      'spark.dynamicAllocation.executorIdleTimeout       60s' \
      > /opt/spark/conf/spark-defaults.conf; \
    chown -R spark:spark /opt/spark/conf /opt/spark/work-dir /home/spark

# HOME defaults to /nonexistent for the spark user (uid 185); point it at a
# dedicated dir (NOT the work-dir, which we mount the repo onto) so JupyterLab's
# runtime/config files don't land in your repo. PYSPARK_PYTHON pins executors to
# the same interpreter as the driver.
ENV HOME=/home/spark \
    SPARK_VERSION=${SPARK_VERSION} \
    PYSPARK_PYTHON=/opt/venv/bin/python \
    PYSPARK_DRIVER_PYTHON=/opt/venv/bin/python

WORKDIR /opt/spark/work-dir
USER spark
