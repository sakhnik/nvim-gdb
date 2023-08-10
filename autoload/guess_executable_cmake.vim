function guess_executable_cmake#ExecutablesOfBuffer(ArgLead)
        " Test ArgLead for CMake directories
        let arg_lead_glob = './' . trim(a:ArgLead) . '*'
        "echom "ArgLead Glob: " arg_lead_glob
        let cmake_dirs = systemlist('find ' . arg_lead_glob . ' -type d -maxdepth 0')
        " Add ArgLead's base directory to the cmake search
        let glob_base_dir = join(split(arg_lead_glob, '/')[0:-2], '/')
        "echom "glob_base_dir: " . glob_base_dir
        let cmake_dirs = add(cmake_dirs, glob_base_dir)
        if v:shell_error
                let cmake_dirs = []
        endif
        " Filter non-CMake directories out
        "echom "Possible CMake Directories: " cmake_dirs
        call map(cmake_dirs, {idx, dir -> luaeval("require'nvimgdb.cmake'.in_cmake_dir(_A[1])", [dir])})
        call filter(cmake_dirs, {idx, dir -> !empty(dir)})
        " Look for CMake directories below this one
        let cmake_dirs = extend(cmake_dirs, luaeval("require'nvimgdb.cmake'.get_cmake_dirs(_A[1])", [glob_base_dir]))
        let cmake_dirs = uniq(sort(cmake_dirs))
        " get binaries from CMake directories
        let execs = flatten(map(cmake_dirs, {idx, cmake_dir -> luaeval("require'nvimgdb.cmake'.executable_of_buffer(_A[1])", [cmake_dir])}))
       call map(execs, {idx, exec -> systemlist('perl -e ''use File::Spec "abs2rel"; use Cwd "abs_path"; print File::Spec->abs2rel(abs_path(shift),abs_path("."))'' '. exec)})
        let execs = uniq(sort(execs))
        return flatten(execs)
endfunction
