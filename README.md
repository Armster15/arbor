# Installing a Python package:

Add dependency to `requirements.txt` and then run `pip3 install --target=./pytest/python_modules -r requirements.txt`.

This installs packages to the `python_modules` dir

# Useful links

- https://docs.python.org/3/using/ios.html#adding-python-to-an-ios-project
  - Follow this to add the Python.xcframework
- https://github.com/beeware/Python-Apple-support
  - To download an already built Python XCFramework
- The Python guide somewhat leaves you on a cliff with "Add Objective C code to initialize and use a Python interpreter in embedded mode".
  - Refer to https://github.com/beeware/Python-Apple-support/blob/main/USAGE.md#using-objective-c for more info
  - This is an example of the Objective-C code required to bootstrap the interpreter: https://github.com/beeware/briefcase-iOS-Xcode-template/blob/main/%7B%7B%20cookiecutter.format%20%7D%7D/%7B%7B%20cookiecutter.class_name%20%7D%7D/main.m
