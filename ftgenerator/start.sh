#!/usr/bin/env bash
# shellcheck disable=SC1000

# generate by 2.3.2
# link (https://github.com/Template-generator/script-genrating/tree/2.3.2)

set -e #ERROR    - Exit whole scripts if single non-zero command return
# set -x #DEBUG    - Display commands and their arguments as they are executed.
# set -v #VERBOSE  - Display shell input lines as they are read.
# set -n #EVALUATE - Check syntax of the script but don't execute.

##################################################################################
## 1.1. (optional) run setup.sh for setup environment and install dependencies  ##
## 1.2. setup logic will check setup.lock file                                  ##
## 2.1. (optional) fetch ftgenerator <version> from github private repository   ##
## 2.2. (optional) install ftgenerator scripts and data to correctly location   ##
## 3.   (optional) fetch latest freqtrade code from Github                      ##
## 4.   (optional) start ftgenerator script                                     ##
## 5.   (optional) move current directory to freqtrade repository               ##
##################################################################################

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

banner() {
  echo
  echo "----------------------------------------"
  echo "$@"
  echo "----------------------------------------"
  echo
}

APP_NAME="ftgenerator"
FREQTRADE_DIRECTORY="/etc/freqtrade"
FT_GENERATOR_DIRECTORY="/etc/$APP_NAME"
DOCKER_DATA_DIRECTORY="/etc/ftdata"
SETUP_LOCK="/etc/ftgenerator/setup.lock"

SETUP_MODE=false     # setup environment
RESET_ROOT=false     # reset root password (should run on GCP only)
FTG_FETCH_MODE=false # download ftgenerator
FT_FETCH_MODE=false  # fetch latest version of freqtrade
FTG_START_MODE=false # start ftgenerator

__setup_msg="[-U|--setup] [-R|--reset-root]"
__fetch_ftg_msg="[-G|--fetch-ftg] [(-t|--token) <token>] [(-v|--version) <v0.0.0>]"
__fetch_ft_msg="[-F|--fetch-ft]"
__start_ftg_msg="[-S|--start-ftg]"

__help_msg="start.sh $__setup_msg $__fetch_ft_msg $__fetch_ftg_msg $__start_ftg_msg"

load_option() {
  while getopts 't:v:URGFMS-:' flag; do
    case "${flag}" in
    U) SETUP_MODE=true ;;
    R) RESET_ROOT=true ;;
    G) FTG_FETCH_MODE=true ;;
    F) FT_FETCH_MODE=true ;;
    S) FTG_START_MODE=true ;;
    t) TOKEN="$OPTARG" ;;
    v) APP_VERSION="$OPTARG" ;;
    -)
      export LONG_OPTARG
      export LONG_OPTVAL
      NEXT="${!OPTIND}"
      set_key_value_long_option "$NEXT"
      case "${OPTARG}" in
      setup)
        no_argument
        SETUP_MODE=true
        ;;
      reset-root)
        no_argument
        RESET_ROOT=true
        ;;
      fetch-ftg)
        no_argument
        FTG_FETCH_MODE=true
        ;;
      start-ftg)
        no_argument
        FTG_START_MODE=true
        ;;
      fetch-ft)
        no_argument
        FT_FETCH_MODE=true
        ;;
      token)
        require_argument
        TOKEN="$LONG_OPTVAL"
        ;;
      version)
        require_argument
        APP_VERSION="$LONG_OPTVAL"
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
OS="darwin"
if [[ $(uname -s) != "Darwin" ]]; then
  OS="linux"
fi

if $SETUP_MODE && [[ "$OS" == "linux" ]]; then
  if ! test -f "$SETUP_LOCK"; then
    banner "Start setup mode"
    __installation_list=(
      "python3-pip"
      "python3-pandas"
      "git"
      "vim"
      "apt-transport-https"
      "curl"
      "ca-certificates"
      "gnupg"
    )

    banner "Update and install new dependencies"
    sudo apt update -y
    sudo apt upgrade -y
    sudo apt install -y "${__installation_list[@]}"

    banner "Install docker"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt update
    sudo apt install -y "docker-ce" "docker-ce-cli" "containerd.io"

    banner "Install docker-compose"
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    if $RESET_ROOT; then
      banner "Reset 'root' password"
      sudo passwd root
    fi

    touch "$SETUP_LOCK" # create setup lock
    unset __installation_list __reset_root_mode
  else
    echo "You has been setup this machine before, to re-setup please delete this file ($SETUP_LOCK)"
  fi
fi

if $FT_FETCH_MODE; then
  banner "Fetch latest freqtrade in default branch"
  if command -v "git" >/dev/null; then
    if test -d $FREQTRADE_DIRECTORY; then
      git -C "$FREQTRADE_DIRECTORY" pull
    else
      git clone 'https://github.com/freqtrade/freqtrade.git' "$FREQTRADE_DIRECTORY"
    fi

  fi
fi

FT_GENEATOR_OUTOUT_DIRECTORY="$FT_GENERATOR_DIRECTORY/${APP_VERSION:-v0.0.0}/"
if $FTG_FETCH_MODE || $FTG_START_MODE; then
  banner "Start ftgenerator fetch=$FTG_FETCH_MODE and start=$FTG_START_MODE"

  if test -z "$APP_VERSION"; then
    echo "needs ftgenerator version, --help for more information"
    exit 1
  fi

  __github_api="https://api.github.com/graphql"
  __github_owner="kamontat"
  __github_repo="$APP_NAME"

  banner "Create ftgenerator on $FT_GENEATOR_OUTOUT_DIRECTORY"

  if $FTG_FETCH_MODE; then
    if ! test -d "$FT_GENEATOR_OUTOUT_DIRECTORY"; then
      if test -z "$TOKEN"; then
        echo "needs github token, --help for more information"
        exit 1
      fi

      __repo_tar="$__github_repo-$OS-${APP_VERSION#*v}.tar.gz" # remove v prefix in version

      __gh_get_asset() {
        query="{\"query\": \"{repository(owner: \\\"$__github_owner\\\", name: \\\"$__github_repo\\\"){release(tagName: \\\"$APP_VERSION\\\") {releaseAssets(name: \\\"$__repo_tar\\\", first: 1) {edges{node{url}}}}}}\"}"

        curl -sL -X POST \
          --header "Authorization: token $TOKEN" --header "Accept: application/vnd.github.v3.raw" \
          -d "$query" "$__github_api"
      }

      __curl() {
        curl --output "$__repo_tar" -L "$@"
      }

      asset_json="$(__gh_get_asset)"
      echo "github response: $asset_json"

      trim_asset_json="${asset_json%\"*}"
      asset_link="${trim_asset_json##*\"}"
      echo "asset url: $asset_link"

      __curl "$asset_link"
      echo "download to $__repo_tar"

      mkdir -p "$FT_GENEATOR_OUTOUT_DIRECTORY" # create directory
      tar -xzvf "$__repo_tar" -C "$FT_GENEATOR_OUTOUT_DIRECTORY"
      rm -r "$__repo_tar"

      unset asset_json trim_asset_json asset_link
      unset __repo_tar
    else
      echo "ftgenerator version $APP_VERSION is already exist"
    fi
  fi

  if $FTG_START_MODE; then
    cd "$FT_GENEATOR_OUTOUT_DIRECTORY" || exit 1
    ./ftgenerator --version
    ./ftgenerator --level 3 --user-data "$FREQTRADE_DIRECTORY/user_data" --docker "$DOCKER_DATA_DIRECTORY"
  fi

  unset __github_api __github_owner __github_repo
fi

banner "## Final information ##
1. Freqtrade   : $FREQTRADE_DIRECTORY
2. FTgenerator : $FT_GENEATOR_OUTOUT_DIRECTORY
3. Docker data : $DOCKER_DATA_DIRECTORY"

unset FREQTRADE_DIRECTORY FT_GENEATOR_OUTOUT_DIRECTORY DOCKER_DATA_DIRECTORY
