#!/usr/bin/python
"""LLDB command to print paths to the source files."""

# import lldb
import os


def dump_module_sources(module, result):
    """."""
    if module:
        files = set()
        print >> result, "Module: %s" % (module.file)
        for compile_unit in module.compile_units:
            for line_entry in compile_unit:
                files.add(os.path.normpath(str(line_entry.GetFileSpec())))
        for f in files:
            print >> result, "  %s" % str(f)


def info_sources(debugger, command, result, dict):
    """."""
    description = "This command will dump all compile units in any modules" \
                  " that are listed as arguments, or for all modules if no" \
                  " arguments are supplied."
    target = debugger.GetSelectedTarget()
    for module in target.modules:
        dump_module_sources(module, result)


def __lldb_init_module(debugger, dict):
    # Add any commands contained in this module to LLDB
    debugger.HandleCommand(
        'command script add -f lldb_sources.info_sources info_sources')
    print('The "info_sources" command has been installed, type' +
          ' "help info_sources" or "info_sources --help" for detailed help.')
