# Jupyter driver image, built FROM the same Apache Spark base as the cluster.
# This guarantees the driver and executors share one Python (3.10) and one
# Spark (4.0.0) version — PySpark refuses to run across mismatched minors.
FROM apache/spark:4.0.0

USER root
RUN set -eux; \
    pip3 install --no-cache-dir jupyterlab; \
    mkdir -p /opt/spark/conf /opt/spark/work-dir /home/spark; \
    chown -R spark:spark /opt/spark/conf /opt/spark/work-dir /home/spark

# HOME defaults to /nonexistent for the spark user (uid 185); point it at a
# dedicated dir (NOT the work-dir, which we mount the repo onto) so JupyterLab's
# runtime/config files don't land in your repo.
# PYTHONPATH makes PySpark importable from a plain notebook kernel.
ENV HOME=/home/spark \
    PYTHONPATH=/opt/spark/python:/opt/spark/python/lib/py4j-0.10.9.9-src.zip \
    PATH=/opt/spark/bin:/opt/spark/sbin:${PATH}

WORKDIR /opt/spark/work-dir
USER spark
