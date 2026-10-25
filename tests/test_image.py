"""Integration checks against the built image; requires a running Docker daemon."""

import json
import os
import subprocess
import time
import unittest
import uuid


class ImageTests(unittest.TestCase):
    image = os.environ.get("JUPYTER_TEST_IMAGE", "jupyter:test")

    def docker(self, *args, timeout=60):
        return subprocess.run(
            ["docker", *args], check=True, capture_output=True, text=True, timeout=timeout
        ).stdout

    def test_dependencies(self):
        """Verify installed dependency compatibility and native library loading."""
        self.docker("run", "--rm", self.image, "pip", "check")
        self.docker(
            "run",
            "--rm",
            self.image,
            "python",
            "-c",
            "import jupyterlab, lightgbm, xgboost, pandas, pyarrow, sklearn; "
            "from pathlib import Path; "
            "Path('/home/jupyter/notebooks/write-check').write_text('writable')",
        )

    def test_server(self):
        """Exercise the default command, health check, user, and authentication."""
        name = f"jupyter-test-{uuid.uuid4().hex}"
        try:
            self.docker("run", "--detach", "--name", name, self.image)
            for _ in range(60):
                state = json.loads(self.docker("inspect", name))[0]["State"]
                if not state["Running"]:
                    self.fail(f"Jupyter exited: {self.docker('logs', name)}")
                if state["Health"]["Status"] == "healthy":
                    break
                time.sleep(1)
            else:
                self.fail(f"Jupyter never became healthy: {self.docker('logs', name)}")

            self.assertEqual(self.docker("exec", name, "id", "-u").strip(), "1000")
            status = self.docker(
                "exec",
                name,
                "curl",
                "--silent",
                "--output",
                "/dev/null",
                "--write-out",
                "%{http_code}",
                "http://localhost:8888/api/contents",
            ).strip()
            self.assertEqual(status, "403", "Contents API should require authentication")
        finally:
            subprocess.run(
                ["docker", "rm", "--force", name],
                check=False,
                capture_output=True,
                timeout=30,
            )


if __name__ == "__main__":
    unittest.main()
