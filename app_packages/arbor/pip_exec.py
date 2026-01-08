import tempfile
from pathlib import Path


# A simple wrapper that lets us programatically call pip.
# We have to do this because pip uses sys.exit(code) and we don't want to exit the program.
def pip_exec(argv: list[str]) -> int:
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
