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

    def logs(self, name):
        result = subprocess.run(
            ["docker", "logs", name],
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )
        return result.stdout + result.stderr

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
        """Verify default startup and access without a token or login."""
        name = f"jupyter-test-{uuid.uuid4().hex}"
        try:
            self.docker("run", "--detach", "--name", name, self.image)
            for _ in range(60):
                state = json.loads(self.docker("inspect", name))[0]["State"]
                if not state["Running"]:
                    self.fail(f"Jupyter exited: {self.logs(name)}")
                if state["Health"]["Status"] == "healthy":
                    break
                time.sleep(1)
            else:
                self.fail(f"Jupyter never became healthy: {self.logs(name)}")

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
            self.assertEqual(status, "200", "Contents API should work without credentials")
            contents = json.loads(
                self.docker(
                    "exec",
                    name,
                    "curl",
                    "--fail",
                    "--silent",
                    "http://localhost:8888/api/contents",
                )
            )
            self.assertEqual(contents["type"], "directory")
            self.assertIn("notebooks", {entry["name"] for entry in contents["content"]})

            lab_status = self.docker(
                "exec",
                name,
                "curl",
                "--silent",
                "--output",
                "/dev/null",
                "--write-out",
                "%{http_code}",
                "http://localhost:8888/lab",
            ).strip()
            self.assertEqual(lab_status, "200", "JupyterLab should open without a login redirect")
        finally:
            subprocess.run(
                ["docker", "rm", "--force", name],
                check=False,
                capture_output=True,
                timeout=30,
            )


if __name__ == "__main__":
    unittest.main()
