FROM python:3.13-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    JUPYTER_ENABLE_LAB=yes \
    PYTHONPATH=/home/jupyter \
    PATH="/opt/venv/bin:$PATH"

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl git libgomp1 nodejs npm pandoc \
    texlive-xetex texlive-fonts-recommended texlive-plain-generic \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/requirements.txt
RUN python -m venv /opt/venv \
    && pip install --upgrade pip \
    && pip install -r /tmp/requirements.txt \
    && pip check

RUN python -c 'import jupyterlab, lightgbm, xgboost, pandas, pyarrow, sklearn' \
    && useradd --create-home --shell /bin/bash --uid 1000 jupyter \
    && mkdir -p /home/jupyter/notebooks /home/jupyter/input_data \
        /home/jupyter/training_data /home/jupyter/output_data /home/jupyter/utilities \
        /home/jupyter/.jupyter/lab/user-settings/@jupyterlab/apputils-extension \
    && echo '{"skipKernelRestartDialog": true}' > /home/jupyter/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/sessionDialogs.jupyterlab-settings \
    && chown -R jupyter:jupyter /home/jupyter

USER jupyter
WORKDIR /home/jupyter/notebooks
EXPOSE 8888

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=5 \
    CMD curl --fail --silent http://localhost:8888/api || exit 1

CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--ServerApp.root_dir=/home/jupyter"]
