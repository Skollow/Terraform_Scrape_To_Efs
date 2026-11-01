"""Assemble the Lambda package in build/lambda: handler source + Linux wheels.

Usage: python scripts/build_lambda.py [python-version]   (default 3.12)
Called by terraform_data.lambda_build; safe to run by hand.
"""
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = ROOT / "lambda"
BUILD_DIR = ROOT / "build" / "lambda"


def main():
    python_version = sys.argv[1] if len(sys.argv) > 1 else "3.12"

    if BUILD_DIR.exists():
        shutil.rmtree(BUILD_DIR)
    BUILD_DIR.mkdir(parents=True)

    # Pull manylinux wheels so the package works on Lambda even when built on Windows/macOS.
    subprocess.run(
        [
            sys.executable, "-m", "pip", "install",
            "--requirement", str(SRC_DIR / "requirements.txt"),
            "--target", str(BUILD_DIR),
            "--platform", "manylinux2014_x86_64",
            "--implementation", "cp",
            "--python-version", python_version,
            "--only-binary=:all:",
            "--quiet",
        ],
        check=True,
    )

    for source in SRC_DIR.glob("*.py"):
        shutil.copy2(source, BUILD_DIR)

    print(f"Lambda package assembled in {BUILD_DIR}")


if __name__ == "__main__":
    main()
