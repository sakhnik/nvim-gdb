let nvim_gdb_default_exec='a.out'

" targets structure is:
" [{artifacts:[...], 
"   link: {commandFragments: [{fragment:"<file_name>", ...}, ...], ...}, 
"   sources: [{path:"<file_name>", ...}...]
"  }, ...]
" Library files (*.a, *.so) are in commandFragments and source files (*.c,
" *.cpp) are in sources
function TargetsThatUseFiles(targets, file_name)
        if match(a:file_name, '\(\.c$\|\.cpp$\)') >= 0
                let Filter_lambda = {idx, val -> match(map(get(val, "sources", []), {idx, source -> source.path}), a:file_name) >= 0}
        elseif match(a:file_name, '\(\.a$\|\.so$\)') >= 0
                let Filter_lambda = {idx, val -> match(map(get(get(val, "link", {}),"commandFragments", []), {idx, commandFragment -> commandFragment.fragment}), split(a:file_name,'/')[-1]) >= 0}
        endif
        return filter(a:targets, Filter_lambda ) 
endfunction

function GetArtifactPaths(targets)
        return map(a:targets, {idx, target-> map(target.artifacts, {idx, artifact -> artifact.path})})
endfunction

function ArtifactsOfFiles(targets, file_name)
        " Filter down to targets that use file_name
        let filtered_targets = TargetsThatUseFiles(a:targets, a:file_name)
        " Get all artifact paths in that target
        return flatten(GetArtifactPaths(filtered_targets))
endfunction

function GetCMakeDirs(proj_dir)
        let find_cmd="find " . a:proj_dir . ' -type f -name CMakeCache.txt'
        echom "find_cmd: '" . find_cmd . "'"
        let cmake_dirs = systemlist(find_cmd)
        echom cmake_dirs
        call map(cmake_dirs, {idx, cmake_dir -> trim(system("dirname " . cmake_dir))})
        return cmake_dirs
endfunction

function ExecutablesOfBuffer(ArgLead)
        let cmake_dirs = GetCMakeDirs(a:ArgLead . '*')
        echom cmake_dirs
        return flatten(map(cmake_dirs, {idx, cmake_dir -> ExecutableOfBuffer(cmake_dir)}))
endfunction

function GetCMakeReplyDir(cmake_build_dir)
        return a:cmake_build_dir . "/.cmake/api/v1/reply/"
endfunction

function ExecutableOfBuffer(cmake_build_dir)
        if CMakeQuery(a:cmake_build_dir) 
                echoerr "nvim-gdb: let g:use_cmake_to_find_executables=0 to NOT use cmake executables for completion"
                return [g:nvim_gdb_default_exec]
        endif
        " Decode all target_file JSONS into Dictionaries
        let targets=split(glob(GetCMakeReplyDir(a:cmake_build_dir) . "target*"))
        call map(targets, {idx, val -> json_decode(readfile(val))})
        let buffer_base_name = bufname() " split(bufname(), '/')[-1]
        let execs = ExecutableOfFileHelper(targets, buffer_base_name, 0)
        let execs = uniq(sort(execs))
        call map(execs, {idx, val -> a:cmake_build_dir . '/' . val})
        return empty(execs) ? [g:nvim_gdb_default_exec] : execs
endfunction

function ExecutableOfFileHelper(targets, file_name, depth)
        let tabs=repeat("  ", a:depth)
        echom tabs.a:file_name
        if match(a:file_name, '\(\.c$\|\.cpp$\|\.a$\|\.so$\)') >= 0
                let artifacts = ArtifactsOfFiles(copy(a:targets), a:file_name)
        else " assume executable found
                echom tabs."found executable: " . a:file_name
                return a:file_name
        endif
        " recurse on all artifacts until executable is found
        echom tabs."recurse with artifacts: ".join(artifacts,', ')
        call map(artifacts, {idx, artifact -> ExecutableOfFileHelper(a:targets, artifact, a:depth+1)})
        return flatten(artifacts)
endfunction

function CMakeQuery(cmake_build_dir)
        if empty(glob(a:cmake_build_dir))
                return v:shell_error
        endif
        let cmake_api_query_dir=a:cmake_build_dir.".cmake/api/v1/query/client-nvim-gdb/"
        call mkdir(cmake_api_query_dir, "p")
        let cmake_api_query_file=cmake_api_query_dir."query.json"
        let cmake_api_query=['{ "requests": [ { "kind": "codemodel" , "version": 2 } ] }']
        call writefile(cmake_api_query, cmake_api_query_file)
        if empty(glob(GetCMakeReplyDir(a:cmake_build_dir)))
                call system("cmake -B ".a:cmake_build_dir)
        endif
        return v:shell_error
endfunction
