let cmake_build_dir="./build/"
let cmake_api_reply_dir=cmake_build_dir . ".cmake/api/v1/reply/"
function ArtifactsOfLibrary(buffer_name)
        let targets=split(glob(g:cmake_api_reply_dir . "target*"))
        " Decode all target_file JSONS into Dictionaries
        call map(targets, {idx, val -> json_decode(readfile(val))})
        " Filter down to targets that use buffer_name as a source
        let Filter_lambda = {idx, val -> match(map(get(get(val, "link", {}),"commandFragments", []), {idx, source -> source.fragment}), a:buffer_name) >= 0}
        call filter(targets, Filter_lambda ) 
        " Get all artifacts that buffer_name generates
        call flatten(map(targets, {idx, target_file -> map(target_file.artifacts, {idx, artifact -> artifact.path})}))
        return targets
endfunction

function ArtifactsOfSource(buffer_name)
        let targets=split(glob(g:cmake_api_reply_dir . "target*"))
        " Decode all target_file JSONS into Dictionaries
        call map(targets, {idx, val -> json_decode(readfile(val))})
        " Filter down to targets that use buffer_name as a source
        let Filter_lambda = {idx, val -> match(map(get(val, "sources", []), {idx, source -> source.path}), a:buffer_name) >= 0}
        call filter(targets, Filter_lambda ) 
        " Get all artifacts that buffer_name generates
        call flatten(map(targets, {idx, target_file -> map(target_file.artifacts, {idx, artifact -> artifact.path})}))
        return targets
endfunction

function ExecutableOfBuffer()
        let artifact_name = split(bufname(), '/')[-1]
        echo "buffer name: ".artifact_name
        while match(artifact_name, '\(\.c$\|\.cpp$\)') >= 0
                let artifact_name=split(get(ArtifactsOfSource(artifact_name), 0), '/')[-1]
                echo "source name: ".artifact_name
        endwhile
        while match(artifact_name, '\(\.a$\|\.so$\)') >= 0
                let artifact_name=split(get(ArtifactsOfLibrary(artifact_name), 0), '/')[-1]
                echo "library name: ".artifact_name
        endwhile
        echo "executable name: ".artifact_name
endfunction

function CmakeQuery()
        let cmake_api_query_dir=g:cmake_build_dir.".cmake/api/v1/query/client-nvim-gdb/"
        call mkdir(cmake_api_query_dir, "p")
        let cmake_api_query_file=cmake_api_query_dir."query.json"
        let cmake_api_query=['{ "requests": [ { "kind": "codemodel" , "version": 2 } ] }']
        call writefile(cmake_api_query, cmake_api_query_file)
        call system("cmake -B ".g:cmake_build_dir)
        echo cmake_api_query_file
endfunction
