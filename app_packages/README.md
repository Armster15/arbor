`app_packages` is configured as a Python site directory. This means that Python recognizes modules from this folder.

Arbor's Python source code lives in the `arbor` package in this folder. This allows us to import our Python code as if it was a library and use it as such.

E.g. usage in Swift:

```py
from arbor import download
result = download('https://www.youtube.com/watch?v=dQw4w9WgXcQ')
```

You can see more in `main.m`.
