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

function InCMakeDir(path)
        " normalize path
        echom "Is " . a:path . " in a CMake Directory?"
        let path=systemlist('readlink -f ' . a:path)[0]
        " check if a CMake Directory
        let idx = 0
        while and('/' != path,  idx < 70)
                echom repeat("  ", idx) . path
                let idx = idx + 1
                if glob(path . '/CMakeCache.txt') != ''
                        echom repeat("  ", idx) . "yes"
                        return path
                endif
                let path=systemlist('readlink -f ' . path . '/../')[0]
        endwhile
        echom repeat("  ", idx) . "No"
        return ''
endfunction

function ExecutablesOfBuffer(ArgLead)
        " Test ArgLead for CMake directories
        echom "ArgLead: " a:ArgLead . '*'
        let cmake_dirs = systemlist('find ' . trim(a:ArgLead) . '* -type d -maxdepth 0')
        " call add(cmake_dirs, join(split(a:ArgLead, '/')[0:-2], '/'))
        if v:shell_error
                let cmake_dirs = []
        endif
        echom "Possible CMake Directories: " cmake_dirs
        call map(cmake_dirs, {idx, dir -> InCMakeDir(dir)})
        call filter(cmake_dirs, {idx, dir -> !empty(dir)})
        " get binaries from CMake directories
        let execs = flatten(map(cmake_dirs, {idx, cmake_dir -> ExecutableOfBuffer(cmake_dir)}))
        " call map(execs, {idx, execs -> systemlist('realpath --relative-to=')})
        return execs
endfunction

function GetCMakeReplyDir(cmake_build_dir)
        return a:cmake_build_dir . "/.cmake/api/v1/reply/"
endfunction

function ExecutableOfBuffer(cmake_build_dir)
        if CMakeQuery(a:cmake_build_dir) 
                return []
        endif
        " Decode all target_file JSONS into Dictionaries
        let targets=split(glob(GetCMakeReplyDir(a:cmake_build_dir) . "target*"))
        call map(targets, {idx, val -> json_decode(readfile(val))})
        let buffer_base_name = bufname() " split(bufname(), '/')[-1]
        let execs = ExecutableOfFileHelper(targets, buffer_base_name, 0)
        let execs = uniq(sort(execs))
        call map(execs, {idx, val -> a:cmake_build_dir . '/' . val})
        return empty(execs) ? [] : execs
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
        let cmake_api_query_dir=a:cmake_build_dir . "/.cmake/api/v1/query/client-nvim-gdb/"
        call mkdir(cmake_api_query_dir, "p")
        let cmake_api_query_file=cmake_api_query_dir."query.json"
        let cmake_api_query=['{ "requests": [ { "kind": "codemodel" , "version": 2 } ] }']
        call writefile(cmake_api_query, cmake_api_query_file)
        if empty(glob(GetCMakeReplyDir(a:cmake_build_dir)))
                call system("cmake -B ".a:cmake_build_dir)
        endif
        return v:shell_error
endfunction
