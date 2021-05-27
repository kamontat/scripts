#!/usr/bin/env bash
# shellcheck disable=SC1000

# generate by 2.3.2
# link (https://github.com/Template-generator/script-genrating/tree/2.3.2)

set -e #ERROR    - Exit whole scripts if single non-zero command return
# set -x #DEBUG    - Display commands and their arguments as they are executed.
# set -v #VERBOSE  - Display shell input lines as they are read.
# set -n #EVALUATE - Check syntax of the script but don't execute.

# 1. Check is previous cache exist, remove all previous cache
# 2. Create random specify version /usr/local/bin/__ftgenerator-start-$RANDOM
# 3. Create runnable command /usr/local/bin/ftgenerator-start = link to specify cache version

__path="/usr/local/bin"
__cached_filename="__ftgenerator-start-$RANDOM"
__cachename="__ftgenerator-cachename"
__executable_filename="ftgenerator-start"

if test -f "$__path/$__cachename"; then
  echo "[info] removing old cache data"

  filename="$(cat "$__path/$__cachename")"
  rm "$__path/$filename"
  rm "$__path/$__cachename"

  unset filename
fi

echo "[info] download new caches ($__cached_filename)"
# download new cache
curl -o "$__path/$__cached_filename" -sL "https://raw.githubusercontent.com/kamontat/scripts/main/ftgenerator/start.sh?random=$RANDOM"

echo "[info] update new caches"
# update new cache name
printf '%s' "$__cached_filename" >"$__path/$__cachename"

if ! test -f "$__path/$__executable_filename"; then
  echo "[info] create executable file"
  # create executable file
  touch "$__path/$__executable_filename"
  echo "#!/usr/bin/env bash

filename=\"\$(cat \"$__path/$__cachename\")\"
bash \"\$filename\" \$@" >>"$__path/$__executable_filename"

  sudo chmod +x $__path/$__executable_filename
fi
