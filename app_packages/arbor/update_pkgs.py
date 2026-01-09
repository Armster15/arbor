from pathlib import Path
from .pip_exec import pip_exec
import contextlib
import importlib.metadata as metadata
import io
import re
import shutil
import traceback

# Base folders
__dirname = Path(__file__).resolve().parent  # node.js my beloved
root_dir = __dirname.parent.parent
application_support_dir = Path.home() / "Library" / "Application Support"

# Core files/dirs
python_modules_dir = root_dir / "python_modules"
updated_python_modules_dir = application_support_dir / "updated_python_modules"
requirements_txt_path = root_dir / "requirements.txt"


def _normalize_name(name: str) -> str:
    return name.strip().lower().replace("-", "_")


def _parse_requirements(path: Path) -> list[str]:
    names: list[str] = []
    for raw_line in path.read_text().splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line or line.startswith("-"):
            continue
        name = re.split(r"[<>=!~\[]", line, maxsplit=1)[0].strip()
        if name:
            names.append(name)
    return names


# Returns a dictionary of package names and their versions from a given path
def _versions_for_path(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    versions: dict[str, str] = {}
    for dist in metadata.distributions(path=[str(path)]):
        name = dist.metadata.get("Name")
        if not name:
            continue
        versions[_normalize_name(name)] = dist.version
    return versions


def update_pkgs() -> tuple[bool, str]:
    log_buffer = io.StringIO()

    with contextlib.redirect_stdout(log_buffer), contextlib.redirect_stderr(log_buffer):
        try:
            result = pip_exec(
                [
                    "install",
                    "--platform=any",
                    "--only-binary=:all:",
                    "--upgrade",
                    "--target=" + str(updated_python_modules_dir),
                    "-r",
                    str(requirements_txt_path),
                ]
            )
            success = result == 0
        except Exception:
            success = False
            traceback.print_exc()

    log_text = log_buffer.getvalue()
    return success, log_text


def are_pkgs_updated() -> bool:
    return updated_python_modules_dir.exists()


def delete_updated_pkgs():
    if updated_python_modules_dir.exists():
        shutil.rmtree(updated_python_modules_dir)


def get_dependency_versions() -> list[dict]:
    requirement_names = _parse_requirements(requirements_txt_path)
    base_versions = _versions_for_path(python_modules_dir)
    updated_versions = _versions_for_path(updated_python_modules_dir)

    output: list[dict] = []
    for name in requirement_names:
        normalized = _normalize_name(name)
        output.append(
            {
                "name": name,
                "base_version": base_versions.get(normalized),
                "updated_version": updated_versions.get(normalized),
            }
        )
    return output
