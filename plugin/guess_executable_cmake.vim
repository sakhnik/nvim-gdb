let cmake_build_dir="./build/"
let cmake_api_reply_dir=cmake_build_dir . ".cmake/api/v1/reply/"
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
                let Filter_lambda = {idx, val -> match(map(get(get(val, "link", {}),"commandFragments", []), {idx, commandFragment -> commandFragment.fragment}), a:file_name) >= 0}
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

function ExecutableOfBuffer()
        if CMakeQuery() 
                echoerr "nvim-gdb: let g:use_cmake_to_find_executables=0 to NOT use cmake executables for completion"
                return [g:nvim_gdb_default_exec]
        endif
        " Decode all target_file JSONS into Dictionaries
        let targets=split(glob(g:cmake_api_reply_dir . "target*"))
        call map(targets, {idx, val -> json_decode(readfile(val))})
        let buffer_base_name = split(bufname(), '/')[-1]
        let execs = ExecutableOfFileHelper(targets, buffer_base_name, 0)
        let execs = uniq(sort(execs))
        call map(execs, {idx, val -> g:cmake_build_dir . val})
        return empty(execs) ? [g:nvim_gdb_default_exec] : execs
endfunction

function ExecutableOfFileHelper(targets, file_name, depth)
        echo repeat("  ", a:depth).a:file_name
        if match(a:file_name, '\(\.c$\|\.cpp$\|\.a$\|\.so$\)') >= 0
                let artifacts = ArtifactsOfFiles(a:targets, a:file_name)
        else " assume executable found
                return a:file_name
        endif
        " recurse on all artifacts until executable is found
        call map(artifacts, {idx, val -> ExecutableOfFileHelper(a:targets, val, a:depth+1)})
        return flatten(artifacts)
endfunction

function CMakeQuery()
        let cmake_api_query_dir=g:cmake_build_dir.".cmake/api/v1/query/client-nvim-gdb/"
        call mkdir(cmake_api_query_dir, "p")
        let cmake_api_query_file=cmake_api_query_dir."query.json"
        let cmake_api_query=['{ "requests": [ { "kind": "codemodel" , "version": 2 } ] }']
        call writefile(cmake_api_query, cmake_api_query_file)
        if empty(glob(g:cmake_api_reply_dir))
                call system("cmake -B ".g:cmake_build_dir)
        endif
        return v:shell_error
endfunction
