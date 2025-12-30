#!/usr/bin/env python

import os
import re
import subprocess
import sys
from packaging import version
import locale


class Prerequisites():
    def __init__(self):
        print("Current locale", locale.getlocale())
        # Check the prerequisites
        self.check_exe_required('nvim', '0.7.2')
        self.check_exe_required('python', '3.9')

        with open("backends.txt", "w") as bf:
            gdb = self.check_exe('gdb', '9')
            if gdb:
                bf.write("gdb\n")
            else:
                lldb = self.check_exe('lldb', '9')
                if lldb:
                    bf.write("lldb\n")
            #bashdb = self.check_exe('bashdb', '5')
            #if bashdb:
            #    bf.write("bashdb\n")
            cmake = self.check_exe('cmake', '3.14.7')  # need File API
            if cmake:
                bf.write("cmake\n")
                self.echo("Running CMake\n")
                generator = []
                if sys.platform == 'win32':
                    # Prefer ninja to Visual Studio
                    generator = ['-G', 'Ninja']
                subprocess.run(['cmake'] + generator +
                               ['src', '-B', 'src/build'])

        self.compile_src()

    def echo(self, msg: str):
        sys.stdout.write(msg)
        sys.stdout.flush()

    def check_exe(self, exe: str, min_version: str) -> str:
        self.echo(f"Check for {exe} (>={min_version})".ljust(32))
        try:
            result = subprocess.run([exe, "--version"],
                                    stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT)
            if result.returncode != 0:
                self.echo("Failed to execute\n")
                return None
        except FileNotFoundError:
            self.echo("Not found\n")
            return None
        output = result.stdout.splitlines()[0].decode('utf-8')
        self.echo(f"{output}\n")
        v = next(re.finditer(r"\d+\.\d+(\.\d+)?", output)).group(0)
        min_version = version.parse(min_version)
        v = version.parse(v)
        if v < min_version:
            return None
        return v

    def check_exe_required(self, exe: str, min_version: str):
        path = self.check_exe(exe, min_version)
        if not path:
            raise RuntimeError(f"{exe} not found")

    def is_file_newer(self, file1, file2):
        try:
            return os.path.getmtime(file1) > os.path.getmtime(file2)
        except FileNotFoundError:
            return True

    def compile_src(self):
        cxx = 'g++' if sys.platform != 'darwin' else 'clang++'
        aout = 'a.out' if sys.platform != 'win32' else 'a.exe'

        self.echo("Compiling test.cpp".ljust(32))

        if self.is_file_newer('src/test.cpp', aout) \
                or self.is_file_newer('src/lib.hpp', aout):
            # Debuggers may be confused if non-absolute paths are used during
            # compilation.
            subprocess.run([cxx, '-g', '-gdwarf-2', '-std=c++11',
                            os.path.realpath('src/test.cpp')])
            self.echo(f"{aout}\n")
        else:
            self.echo(f"(cached {aout})\n")


def main():
    Prerequisites()


if __name__ == "__main__":
    main()
