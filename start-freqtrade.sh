#!/usr/bin/env bash
# shellcheck disable=SC1000

# generate by 2.3.2
# link (https://github.com/Template-generator/script-genrating/tree/2.3.2)

set -e # If error occurred, exit all scripts

# set -x #DEBUG - Display commands and their arguments as they are executed.
# set -v #VERBOSE - Display shell input lines as they are read.
# set -n #EVALUATE - Check syntax of the script but don't execute.

# @helper
throw() {
  printf '%s\n' "$1" >&2 && exit "$2"
  return 0
}

# @helper
throw_if_empty() {
  local text="$1"
  test -z "$text" && throw "$2" "$3"
  return 0
}

# @option
require_argument() {
  throw_if_empty "$LONG_OPTVAL" "'$LONG_OPTARG' require argument" 9
}

# @option
no_argument() {
  [[ -n $LONG_OPTVAL ]] && ! [[ $LONG_OPTVAL =~ "-" ]] && throw "$LONG_OPTARG don't have argument" 9
  OPTIND=$((OPTIND - 1))
}

# @syscall
set_key_value_long_option() {
  if [[ $OPTARG =~ "=" ]]; then
    LONG_OPTVAL="${OPTARG#*=}"
    LONG_OPTARG="${OPTARG%%=$LONG_OPTVAL}"
  else
    LONG_OPTARG="$OPTARG"
    LONG_OPTVAL="$1"
    OPTIND=$((OPTIND + 1))
  fi
}

DEBUG_MODE=false
SETUP_MODE=false
LOAD_ENABLED=true

__token_msg="[(-t|--token) <token>]"
__version_msg="[(-v|--version) v0.0.0]"
__debug_msg="[-D|--debug]"
__setup_msg="[-S|--setup]"
__no_load_msg="[-N|--no-load]"
__help_msg="start.sh $__token_msg $__version_msg $__debug_msg $__setup_msg $__no_load_msg"

load_option() {
  while getopts 't:v:DSN-:' flag; do
    case "${flag}" in
    t) TOKEN="$OPTARG" ;;
    v) APP_VERSION="$OPTARG" ;;
    D) DEBUG_MODE=true ;;
    S) SETUP_MODE=true ;;
    N) LOAD_ENABLED=false ;;
    -)
      export LONG_OPTARG
      export LONG_OPTVAL
      NEXT="${!OPTIND}"
      set_key_value_long_option "$NEXT"
      case "${OPTARG}" in
      token)
        require_argument
        TOKEN="$LONG_OPTVAL"
        ;;
      version)
        require_argument
        APP_VERSION="$LONG_OPTVAL"
        ;;
      debug)
        no_argument
        DEBUG_MODE=true
        ;;
      setup)
        no_argument
        SETUP_MODE=true
        ;;
      no-load)
        no_argument
        LOAD_ENABLED=false
        ;;
      *)
        # because optspec is assigned by 'getopts' command
        # shellcheck disable=SC2154
        if [ "$OPTERR" == 1 ] && [ "${optspec:0:1}" != ":" ]; then
          echo "Unexpected option '$LONG_OPTARG', $__help_msg" >&2
          exit 9
        fi
        ;;
      esac
      ;;
    ?)
      echo "Unexpected option, $__help_msg" >&2
      exit 10
      ;;
    *)
      echo "Unexpected option $flag, $__help_msg" >&2
      exit 10
      ;;
    esac
  done
}

load_option "$@"

GITHUB_API="https://api.github.com/graphql"
OWNER="kamontat"
REPO="freqtrade-personal"
if test -z "$TOKEN"; then
  echo "needs token, $__token_msg"
  exit 1
fi
if test -z "$APP_VERSION"; then
  echo "needs freqtrade version, $__version_msg"
  exit 1
fi

OS="darwin"
if [[ $(uname -s) != "Darwin" ]]; then
  OS="linux"
fi

# freqtrade-generators-darwin-2.0.0-beta.8.tar.gz
FILENAME="freqtrade-generators-$OS-${APP_VERSION#*v}.tar.gz" # remove v prefix in version

__gh_get_asset() {
  query="{\"query\": \"{repository(owner: \\\"$OWNER\\\", name: \\\"$REPO\\\"){release(tagName: \\\"$APP_VERSION\\\") {releaseAssets(name: \\\"$FILENAME\\\", first: 1) {edges{node{url}}}}}}\"}"

  curl -sL -X POST \
    --header "Authorization: token $TOKEN" --header "Accept: application/vnd.github.v3.raw" \
    -d "$query" "$GITHUB_API"
}

__curl() {
  curl --output "$FILENAME" -L "$@"
}

if $LOAD_ENABLED; then
  asset_json="$(__gh_get_asset)"
  if $DEBUG_MODE; then
    echo "github response: $asset_json"
  fi

  trim_asset_json="${asset_json%\"*}"
  asset_link="${trim_asset_json##*\"}"
  if $DEBUG_MODE; then
    echo "asset url: $asset_link"
  fi

  __curl "$asset_link"
  if $DEBUG_MODE; then
    echo "download to $FILENAME"
  fi

  tar -xzvf "$FILENAME" -C .
  rm -r "$FILENAME"
fi

__freqtrade_dirname="freqtrade"
if command -v "git" >/dev/null; then
  if ! test -d "$__freqtrade_dirname/.git"; then
    rm -r "$__freqtrade_dirname"
    git clone 'https://github.com/freqtrade/freqtrade.git' "$__freqtrade_dirname"
  fi
fi

# generator data
./freqtrade-generators

# run setup.sh
if $SETUP_MODE && [[ $OS == "linux" ]]; then
  if $DEBUG_MODE; then
    echo "start setup scripts"
  fi

  bash "freqtrade/user_data/scripts/setup.sh"

  echo "----------------------------------------"
  echo "1. delete freqtrade | rm -r freqtrade
2. clone freqtrade  | git clone 'https://github.com/freqtrade/freqtrade.git'
3. reinitial data   | ./freqtrade-generators"
  echo "----------------------------------------"
fi
