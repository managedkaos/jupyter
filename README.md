# Shared Jupyter environment

A reusable Python 3.13 image based on the Docker environment in
`time-series-modeling-with-xgboost`. It includes JupyterLab, Notebook, widgets,
the packages in `requirements.txt`, Git, Node.js/npm, Pandoc, and LaTeX for PDF
export. LightGBM's OpenMP runtime is included. Jupyter runs as the non-root
`jupyter` user (UID 1000).

## Use in any project

Copy `compose.yml` into the project, then run:

```sh
mkdir -p notebooks input_data training_data output_data utilities
docker compose pull
docker compose up -d
```

Open http://localhost:8888 directly; no token or password is required.
The port is bound to localhost. The notebook
browser opens at `/home/jupyter`, with all five mounted project folders visible.
Changes in these folders persist on the host. Linux host folders must be writable
by UID 1000. The source project's `utilties` mount typo is corrected to `utilities`.

Compose pulls `ghcr.io/managedkaos/jupyter:main`; it does not build an image.
Override the image or port through your shell or a Compose `.env` file:

```sh
JUPYTER_IMAGE=ghcr.io/managedkaos/jupyter:abc1234 JUPYTER_PORT=8889 docker compose up -d
```

Replace `abc1234` with a published commit SHA tag. Use a commit SHA tag or image
digest to keep multiple projects on the same build.
`main` tracks the default branch. Dependencies and the base image are not locked;
rebuilding a tag's source later may resolve newer packages. No project notebooks,
datasets, or `.env` files are copied into the image.

## Build locally

```sh
docker build -t jupyter:local .
JUPYTER_IMAGE=jupyter:local docker compose up -d
```

To check installed packages:

```sh
docker run --rm jupyter:local pip check
docker run --rm jupyter:local python -c 'import jupyterlab, lightgbm, xgboost, pandas, pyarrow, sklearn'
```

## Publish with GitHub Actions

`.github/workflows/image.yml` builds the Dockerfile for Linux AMD64 and ARM64.
Pull requests build without publishing. All pushes and manual
runs publish to `ghcr.io/<owner>/<repository>` using the built-in `GITHUB_TOKEN`
with `packages: write`; no separate registry secret is required. The workflow
includes OCI labels and archives the Docker metadata as a workflow artifact.
The jobs run in order: `lint → build → test → push`. The build job generates
metadata and builds both platforms once, saving the image with its tags and
labels as an artifact. The test job loads that artifact and runs the integration
tests on both platforms (ARM64 uses QEMU). Once tests pass, the push job loads
the same artifact and pushes its existing tags without rebuilding. Docker's
containerd image store preserves both platforms through save, load, and push.
Pull requests skip the push job.

The build job restores and saves Docker layers using the GitHub Actions cache
(`type=gha`, scope `jupyter-image`, `mode=max`). After the first run populates the
cache, unchanged system and Python dependency layers can be reused across runs.
Changing `requirements.txt` rebuilds the Python installation layer and subsequent
layers while preserving the system package layer. Image artifact transfers and
tests still run even when the build uses cached layers.

Images receive short and full commit SHA tags and, for branch builds, a branch
tag. Git version tags do not produce semantic version image tags. After the first
publication, set the GitHub package visibility to public if projects should pull
without authentication. Private packages require a GHCR login with package read
access. The shared image must be published before the default Compose example
can pull it.

## Development checks

Python 3.14 runs the
development tools; the notebook image uses Python 3.13. Install the tools in an
isolated virtual environment, then run the same checks locally:

```sh
make development-requirements
make lint
make pre-commit-install pre-commit-run
make test
```

Ruff checks and formats the Python tests, and pre-commit also validates Compose.
Pre-commit checks tracked files; stage new files before running it locally.
`make test` requires Docker and builds `jupyter:test` before running unittest
integration checks for dependencies, writable notebooks, non-root execution,
server health, and access without authentication. Temporary test containers are removed afterward.
Use `make` to see all targets, or `make test IMAGE=jupyter:local` to choose a local
image tag. Use `make test-image` to test an existing image without rebuilding.
Local tests use the host architecture by default; CI tests both platforms.
