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
        "echom "Is " . a:path . " in a CMake Directory?"
        let path=systemlist('perl -e ''use Cwd "abs_path"; print abs_path(shift)'' ' . a:path)[0]
        " check if a CMake Directory
        let idx = 0
        while and('/' != path,  idx < 70)
                "echom repeat("  ", idx) . path
                let idx = idx + 1
                if glob(path . '/CMakeCache.txt') != ''
                        "echom repeat("  ", idx) . "yes"
                        return path
                endif
                let path=systemlist('perl -e ''use Cwd "abs_path"; print abs_path(shift)'' ' . path . '/../')[0]
        endwhile
        "echom repeat("  ", idx) . "No"
        return ''
endfunction

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
        call map(cmake_dirs, {idx, dir -> InCMakeDir(dir)})
        call filter(cmake_dirs, {idx, dir -> !empty(dir)})
        " Look for CMake directories below this one
        let cmake_dirs = extend(cmake_dirs, GetCMakeDirs(glob_base_dir))
        let cmake_dirs = uniq(sort(cmake_dirs))
        " get binaries from CMake directories
        let execs = flatten(map(cmake_dirs, {idx, cmake_dir -> ExecutableOfBuffer(cmake_dir)}))
       call map(execs, {idx, exec -> systemlist('perl -e ''use File::Spec "abs2rel"; use Cwd "abs_path"; print File::Spec->abs2rel(abs_path(shift),abs_path("."))'' '. exec)})
        let execs = uniq(sort(execs))
        return flatten(execs)
endfunction

function GetCMakeDirs(proj_dir)
        let find_cmd="find " . a:proj_dir . ' -type f -name CMakeCache.txt'
        "echom "find_cmd: '" . find_cmd . "'"
        let cmake_dirs = systemlist(find_cmd)
        "echom cmake_dirs
        call map(cmake_dirs, {idx, cmake_dir -> trim(system("dirname " . cmake_dir))})
        "echom "cmake dirnames: " cmake_dirs
        return cmake_dirs
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
        let cmake_source = json_decode(readfile(glob(GetCMakeReplyDir(a:cmake_build_dir) . "codemodel*json"))).paths.source
        let buffer_base_name = systemlist('perl -e ''use File::Spec; use Cwd "abs_path"; print File::Spec->abs2rel(abs_path(shift), abs_path(shift))'' ' . bufname() ." ". cmake_source )[0]
        let execs = ExecutableOfFileHelper(targets, buffer_base_name, 0)
        call map(execs, {idx, val -> a:cmake_build_dir . '/' . val})
        return empty(execs) ? [] : execs
endfunction

function ExecutableOfFileHelper(targets, file_name, depth)
        let tabs=repeat("  ", a:depth)
        "echom tabs.a:file_name
        if match(a:file_name, '\(\.c$\|\.cpp$\|\.a$\|\.so$\)') >= 0
                let artifacts = ArtifactsOfFiles(copy(a:targets), a:file_name)
        else " assume executable found
                "echom tabs."found executable: " . a:file_name
                return [a:file_name]
        endif
        " recurse on all artifacts until executable is found
        "echom tabs."recurse with artifacts: ".join(artifacts,', ')
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
