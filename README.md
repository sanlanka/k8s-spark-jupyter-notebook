# Spark + Jupyter on Kubernetes

A standalone **Apache Spark 4.0.0** cluster (master + worker) plus a **Jupyter**
notebook that connects to it — deployed with one command via **Skaffold** and a
small custom **Helm** chart.

## Quick start

```bash
./spinup.sh
```

That's it. The script installs any missing tooling (kubectl, helm, skaffold),
builds the Jupyter image, deploys everything, and holds the port-forwards:

- Jupyter → **http://localhost:8888** (token: `spark123`)
- Spark master UI → **http://localhost:8080**

Press `Ctrl-C` to stop the port-forwards (the cluster keeps running). To remove
everything: `./teardown.sh` (add `--namespace` to delete the `api` namespace).

**Prerequisites:** Docker Desktop with Kubernetes enabled (or minikube). On
macOS the script auto-installs the CLI tools via Homebrew.

## Use it

In a notebook, connect with a plain builder — the driver host and Python
version are already wired up:

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("MyApp") \
    .master("spark://spark-master:7077") \
    .getOrCreate()

print(spark.version)                                    # 4.0.0
print(spark.sparkContext.parallelize(range(1, 101)).sum())   # 5050
spark.stop()
```

## Reading data files

The pods can't see your Mac's filesystem, so **files you want to read must live
in one of the exposed folders** — by default `notebooks/` and `test-datasets/`.
These are bind-mounted (via `spinup.sh`) as siblings at Jupyter's root *and* onto
the workers, so paths resolve identically everywhere and the Jupyter file browser
stays clean (no `charts/`, `docker/`, `.git`, scripts). Drop CSVs in
`test-datasets/` and use a path relative to your notebook:

```python
# from a notebook in notebooks/ :
df = (spark.read
      .option("header", True)
      .option("inferSchema", True)
      .csv("../test-datasets/retail_sales.csv"))
```

Path rules:
- The relative path is relative to **where your notebook lives** (Jupyter runs
  each kernel from the notebook's folder). Notebook in `notebooks/` →
  `../test-datasets/x.csv`; notebook at the repo root → `test-datasets/x.csv`.
- An absolute in-pod path always works too: `/opt/spark/work-dir/test-datasets/x.csv`.
- A host path like `/Users/you/...` will **not** work — it doesn't exist in the pod.
- To expose another folder, add it to `hostMount.paths` in `charts/spark/values.yaml`.
- In cluster mode the **executors** read the file too; that's why the repo is
  mounted on the workers as well (same absolute path on every pod).
- This uses a `hostPath` mount and works on Docker Desktop / minikube (they share
  `/Users`). On a remote/multi-node cluster, use object storage (S3/GCS) or a
  PersistentVolume instead.

## How it fits together

- **`skaffold.yaml`** — builds the Jupyter image and deploys the Helm chart;
  the `portForward` block does all forwarding (no manual `kubectl port-forward`).
- **`charts/spark/`** — the Helm chart (master, worker, Jupyter). Tune it in
  `charts/spark/values.yaml` (worker `replicas`, cores, memory, token).
- **`docker/jupyter/Dockerfile`** — Jupyter image built **FROM `apache/spark:4.0.0`**
  so the driver and executors share one Python (3.10) and Spark (4.0.0). This
  matters: PySpark refuses to run across mismatched Python minor versions.
- **`notebooks/`** — put your `.ipynb` files here.

### Images

All public, no Bitnami (Bitnami removed its free Docker Hub images in Aug 2025):

| Role          | Image                                    |
|---------------|------------------------------------------|
| Master/worker | `apache/spark:4.0.0` (Docker Hub)        |
| Jupyter       | built from `apache/spark:4.0.0` + JupyterLab |

## Troubleshooting

```bash
kubectl get pods -n api
kubectl logs -l app=spark-master -n api      # look for "Registering worker"
kubectl logs -l app=jupyter-pyspark -n api
```

- **Job hangs on "Initial job has not accepted any resources"** — the worker
  isn't registered or the driver isn't reachable. Check the master log for
  `Registering worker`; the chart sets `spark.driver.host` to the pod IP for you.
- **`PYTHON_VERSION_MISMATCH`** — driver and executor Python differ. Keep the
  Jupyter image built from the same `apache/spark` base as the cluster.
- **Master crashes parsing `tcp://...:7077`** — a Kubernetes service-link env
  var collided with Spark's `SPARK_MASTER_PORT`. The chart disables that with
  `enableServiceLinks: false`.

## Scale

Edit `charts/spark/values.yaml` (`spark.worker.replicas`) and re-run `./spinup.sh`.
