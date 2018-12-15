if [[ -n "$ZSH_VERSION" ]]; then
    this_dir=`dirname ${(%):-%N}`
elif [[ -n "$ZSH_VERSION" ]]; then
    this_dir=`dirname ${BASH_SOURCE[0]}`
else
    this_dir=`pwd`
fi

export LUA_PATH='/home/sakhnik/.luarocks/share/lua/5.1/?.lua;/home/sakhnik/.luarocks/share/lua/5.1/?/init.lua;/tmp/nvim-gdb/lua/rocks/share/lua/5.1/?.lua;/tmp/nvim-gdb/lua/rocks/share/lua/5.1/?/init.lua;/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;./?.lua;/usr/lib/lua/5.1/?.lua;/usr/lib/lua/5.1/?/init.lua'
export LUA_CPATH='/home/sakhnik/.luarocks/lib/lua/5.1/?.so;/tmp/nvim-gdb/lua/rocks/lib/lua/5.1/?.so;/usr/lib/lua/5.1/?.so;./?.so;/usr/lib/lua/5.1/loadall.so'
export PATH='/home/sakhnik/.luarocks/bin:/tmp/nvim-gdb/lua/rocks/bin:./../lua/rocks/bin:/home/sakhnik/work/dotfiles/.zplug/repos/zplug/zplug/bin:/home/sakhnik/work/dotfiles/.zplug/bin:/home/sakhnik/work/dotfiles/src/.bin:/home/sakhnik/.gem/ruby/2.5.0/bin:/home/sakhnik/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/opt/android-sdk/platform-tools:/usr/lib/jvm/default/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl:/sbin:/usr/sbin:/home/sakhnik/work/dotfiles/src/.vim/plugged/fzf/bin'
