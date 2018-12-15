if [[ -n "$ZSH_VERSION" ]]; then
    this_dir=`dirname ${(%):-%N}`
elif [[ -n "$ZSH_VERSION" ]]; then
    this_dir=`dirname ${BASH_SOURCE[0]}`
else
    this_dir=`pwd`
fi

export LUAROCKS_TREE=$this_dir/../lua/rocks
eval `luarocks path`
