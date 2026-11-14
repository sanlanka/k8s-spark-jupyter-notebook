# One image for EVERY pod — Spark master, workers, the Spark Connect server and
# Jupyter. PySpark refuses to run when the driver and executors use different
# Python minor versions, so they must all share this exact interpreter.
#
# Don't edit the versions here: set them under `versions:` in
# charts/spark/values.yaml. spinup.sh reads that block and Skaffold passes the
# values in as these build args. The defaults below only apply to a bare
# `docker build`.
ARG SPARK_VERSION=4.1.0
ARG JAVA_VERSION=17

# Stock Apache Spark distribution, *without* the bundled Python — we bring our own.
FROM apache/spark:${SPARK_VERSION}-scala2.13-java${JAVA_VERSION}-ubuntu

ARG SPARK_VERSION
ARG PYTHON_VERSION=3.12
ARG DELTA_SPARK_VERSION=4.2.0

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
    # Make the distribution's own PySpark + py4j importable (no version hardcoding).
    site="$(python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"; \
    { echo /opt/spark/python; ls /opt/spark/python/lib/py4j-*-src.zip; } > "${site}/pyspark-dist.pth"; \
    python -c "import pyspark, delta; print('pyspark', pyspark.__version__)"

# --- Delta Lake jars, baked into Spark's classpath (no runtime --packages) ---
# Delta >= 4.1 publishes one artifact per Spark minor (delta-spark_4.1_2.13);
# older releases use delta-spark_2.13. Resolve with Spark's own Ivy, then copy
# only the jars Spark doesn't already ship so Spark's versions always win.
RUN set -eux; \
    mm="${SPARK_VERSION%.*}"; \
    artifact="delta-spark_${mm}_2.13"; \
    curl -fsI "https://repo1.maven.org/maven2/io/delta/${artifact}/${DELTA_SPARK_VERSION}/" >/dev/null \
      || artifact="delta-spark_2.13"; \
    spark-submit --master 'local[1]' --conf spark.jars.ivy=/tmp/ivy \
      --packages "io.delta:${artifact}:${DELTA_SPARK_VERSION}" \
      --class org.apache.spark.examples.SparkPi /opt/spark/examples/jars/spark-examples_*.jar 1 \
      2>&1 | grep -q 'Pi is roughly' || { echo "Delta ${DELTA_SPARK_VERSION} did not resolve for Spark ${SPARK_VERSION}"; exit 1; }; \
    for jar in /tmp/ivy/jars/*.jar; do \
      name="$(basename "$jar" .jar)"; name="${name#*_}"; \
      name="$(echo "$name" | sed -E 's/-[0-9][^-]*(-.*)?$//')"; \
      ls /opt/spark/jars | grep -q "^${name}-[0-9]" || cp "$jar" /opt/spark/jars/; \
    done; \
    rm -rf /tmp/ivy /root/.ivy2*; \
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
