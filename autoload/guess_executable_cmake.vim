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
        let execs = flatten(map(cmake_dirs, {idx, cmake_dir -> ExecutableOfBuffer(cmake_dir)}))
       call map(execs, {idx, exec -> systemlist('perl -e ''use File::Spec "abs2rel"; use Cwd "abs_path"; print File::Spec->abs2rel(abs_path(shift),abs_path("."))'' '. exec)})
        let execs = uniq(sort(execs))
        return flatten(execs)
endfunction

function ExecutableOfBuffer(cmake_build_dir)
        if luaeval("require'nvimgdb.cmake'.query(_A[1])", [a:cmake_build_dir])
                return []
        endif
        let reply_dir = luaeval("require'nvimgdb.cmake'.get_cmake_reply_dir(_A[1])", [a:cmake_build_dir])
        " Decode all target_file JSONS into Dictionaries
        let targets=split(glob(reply_dir . "target*"))
        call map(targets, {idx, val -> json_decode(readfile(val))})
        let cmake_source = json_decode(readfile(glob(reply_dir . "codemodel*json"))).paths.source
        let buffer_base_name = systemlist('perl -e ''use File::Spec; use Cwd "abs_path"; print File::Spec->abs2rel(abs_path(shift), abs_path(shift))'' ' . bufname() ." ". cmake_source )[0]
        let execs = luaeval("require'nvimgdb.cmake'.executable_of_file_helper(_A[1], _A[2])", [targets, buffer_base_name])
        call map(execs, {idx, val -> a:cmake_build_dir . '/' . val})
        return empty(execs) ? [] : execs
endfunction
