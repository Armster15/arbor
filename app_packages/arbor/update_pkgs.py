import tempfile
from pathlib import Path


def pip_main_no_exit(argv):
    try:
        from pip._internal.cli.main import main

        rc = main(argv)
        # pip sometimes returns None for success
        return 0 if rc is None else int(rc)
    except SystemExit as e:
        # pip frequently uses sys.exit(code)
        code = e.code
        if code is None:
            return 0
        if isinstance(code, int):
            return code
        return 1  # non-int codes become failure


temp_site_modules_dir = Path(tempfile.mkdtemp(prefix="pip-temp-site-modules-"))


rc = pip_main_no_exit(
    [
        "install",
        "--target",
        str(temp_site_modules_dir),
        "--only-binary",
        ":all:",
        "requests",
    ]
)


print(rc)
print(temp_site_modules_dir)
