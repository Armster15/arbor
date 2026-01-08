from pathlib import Path
from .pip_exec import pip_exec
import shutil

application_support_dir = Path.home() / "Library" / "Application Support"
# configured as a site dir in main.m
updated_python_mods_dir = application_support_dir / "updated_python_modules"


def update_pkgs() -> bool:
    # Get path to requirements.txt
    __dirname = Path(__file__).resolve().parent  # node.js my beloved
    r_txt_path = str(__dirname.parent.parent / "requirements.txt")

    # 3. Install dependencies
    result = pip_exec(
        [
            "install",
            "--platform=any",
            "--only-binary=:all:",
            "--upgrade",
            "--target=" + str(updated_python_mods_dir),
            "-r",
            r_txt_path,
        ]
    )

    return result == 0


def are_pkgs_updated() -> bool:
    return updated_python_mods_dir.exists()


def delete_updated_pkgs():
    if updated_python_mods_dir.exists():
        shutil.rmtree(updated_python_mods_dir)
