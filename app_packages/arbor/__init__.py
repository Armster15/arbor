from .download import download
from .lyrics import get_lyrics_from_youtube
from .search import search_youtube, search_soundcloud
from .pip_exec import pip_exec
from .update_pkgs import (
    update_pkgs,
    are_pkgs_updated,
    delete_updated_pkgs,
    get_dependency_versions,
)

version = "1.0.0"
