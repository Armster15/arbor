//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import <Foundation/Foundation.h>
#include <Python/Python.h>

void crash_dialog(NSString *details);
NSString * format_traceback(PyObject *type, PyObject *value, PyObject *traceback);

int start_python_runtime(int argc, char *argv[]);

// Python bridge API exposed to Swift
void finalize_python_runtime(void);
int pythonRunSimpleString(NSString *code);
NSString * pythonExecAndGetString(NSString *code, NSString *variableName);

