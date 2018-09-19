#!/usr/bin/env bash

usage()
{
cat << EOF

Command Runner



EOF
}

confirm()
{
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure? [y/N]} " response
    case "$response" in
        [yY])
            true
            ;;
        *)
            false
            ;;
    esac
}

# Initialize variables
TARGET=
VERBOSE=
GPGAUTH=
COMMAND=
BECOME=
LIMITTO="all"
SKIPASKPW=no
dummy_arg="__dummy__"
extra_args=("${dummy_arg}") # Because set -u does not allow undefined variables to be used
discard_opts_after_doubledash=0 # 1=Discard, 0=Save opts after -- to ${extra_args}

PREGETOPT="$*"

getopt --test > /dev/null
if [[ $? -ne 4 ]]; then
    echo "I'm sorry, 'getopt --test' failed in this environment."
    exit 1
fi

# An option followed by a single colon ':' means that it *needs* an argument.
# An option followed by double colons '::' means that its argument is optional.
# See `man getopt'.
SHORT=sbvht:a:l:                                       # List all the short options
LONG=skippw,become,verbose,help,target:,auth:,limitto: # List all the long options

# - Temporarily store output to be able to check for errors.
# - Activate advanced mode getopt quoting e.g. via "--options".
# - Pass arguments only via   -- "$@"   to separate them correctly.
# - getopt auto-adds "--" at the end of ${PARSED}, which is then later set to
#   "$@" using the set command.
PARSED=$(getopt --options ${SHORT} \
                --longoptions ${LONG} \
                --name "$0" \
                -- "$@")         #Pass all the args to this script to getopt
if [[ $? -ne 0 ]]; then
    # e.g. $? == 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi
# Use eval with "$PARSED" to properly handle the quoting
# The set command sets the list of arguments equal to ${PARSED}.
eval set -- "${PARSED}"

# echo "Getopt parsed arguments: ${PARSED}"
# echo "Effective arguments: $*"
# echo "Num args: $#"

while [[ ( ${discard_opts_after_doubledash} -eq 1 ) || ( $# -gt 0 ) ]]
do
    # echo "parsing arg: $1"
    case "$1" in
        -h|--help)
                   usage
                   exit 1
                   ;;
        -b|--become)
                   BECOME=1
                   ;;
        -v|--verbose)
                   VERBOSE=vvv
                   ;;
        -t|--target)
                   shift
                   TARGET="$1"
                   ;;
        -l|--limitto)
                   shift
                   LIMITTO="$1"
                   ;;
        -a|--auth)
                   shift
                   GPGAUTH="$1"
                   ;;
        -s|--skippw)
                   SKIPASKPW=
                   ;;
        --)
                   if [[ ${discard_opts_after_doubledash} -eq 1 ]]
                   then
                       break;
                   else
                       shift
                       extra_args=("${extra_args[@]}" "$*")
                       break;
                   fi
                   ;;
        *) extra_args=("${extra_args[@]}" "$1");;
    esac
    shift                       # Expose the next argument
done

# Now delete the ${dummy_arg} from ${extra_args[@]} array # http://stackoverflow.com/a/16861932/1219634
extra_args=("${extra_args[@]/${dummy_arg}}")
# Insert command, stripping leading space that somehow gets into it.
COMMAND="${extra_args[*]:1}"

# We need a command and a target (hostfile), always
if [[ -z $COMMAND ]]
then
     echo "No command"
     echo ""
     usage
     exit 1
fi

if [[ -z $TARGET ]]
then
     echo "No target"
     echo ""
     usage
     exit 1
fi

# Check if target hosts file exists
if [[ ! -f inventories/hosts.$TARGET ]] && [[ ! -d inventories/hosts.$TARGET ]]
then
     echo "hosts file for $TARGET does not exist!"
     exit 1
fi

# Check if gpg file exists if specified
if [[ ! -z $GPGAUTH ]]
then
     if [[ ! -f $GPGAUTH ]]
     then
          echo "GPG File $GPGAUTH does not exist!"
          exit 1
     fi
fi

# When limiting, check to ensure the server or group actually is defined in the hostfile
# so we don't go thru an entire playbook without action
FOUNDLIMIT=
if [[ "$LIMITTO" != "all" ]]
then
     checklimit=$(echo $LIMITTO | tr ":" "\n")
     for limit in $checklimit
     do
          if [[ ! $(grep "\[$limit\]" inventories/hosts.$TARGET) ]] && [[ ! $(grep "\[$limit:children\]" inventories/hosts.$TARGET) ]]
          then
               # not found
               echo "$limit is not specified as a server or group in hosts.$TARGET!"
               exit 1
          else
               if [[ $(grep "\[$limit\]" inventories/hosts.$TARGET) ]]
               then
                    FOUNDLIMIT+="  `grep "\[$limit\]" inventories/hosts.$TARGET`\n"
               else
                    FOUNDLIMIT+="  `grep "\[$limit:children\]" inventories/hosts.$TARGET`\n"
               fi
          fi
          if [[ -z $FOUNDLIMIT ]]
          then
               # safeguard, should never happen.
               echo "Did not find any specified server or group."
               exit 1
          fi
     done
fi

# form the command we want to run
ANSIBLE_COMMAND="LC_ALL=C ansible -v${VERBOSE} -i inventories/hosts.${TARGET} -m shell -a '${COMMAND}' ${LIMITTO//[[:space:]]}"

if [[ $BECOME ]]
then
     ANSIBLE_COMMAND+=" --become"
     if [[ ! $TARGET == "devops-CnC" ]]
     then
          if [[ -z $GPGAUTH ]]
          then
               if [[ ! $TARGET == "vm" ]]
               then
                   if [[ ! -z $SKIPASKPW ]]
                   then
                        ANSIBLE_COMMAND+=" --ask-become-pass"
                   else
                        SKIPASKPW=yes
                   fi
               else
                    ANSIBLE_COMMAND+=' --extra-vars "ansible_become_pass=foo"'
               fi
          else
               ANSIBLE_COMMAND+=' --extra-vars "ansible_become_pass=`gpg --output - --decrypt '
               ANSIBLE_COMMAND+="$GPGAUTH"
               ANSIBLE_COMMAND+='`"'
          fi
     fi
fi

echo ""
echo "=================================="
echo "$0 ${PREGETOPT}"
echo "=================================="
echo "VERBOSE          == $VERBOSE"
echo "TARGET           == $TARGET"
echo "LIMITTO          == $LIMITTO"
echo "GPGAUTH          == $GPGAUTH"
echo "COMMAND          == $COMMAND"
echo "SKIPASKPW        == $SKIPASKPW"
if [[ ! -z $FOUNDLIMIT ]]
then
     echo ""
     echo "Found the following server(s) or group(s) to limit too :"
     echo -e "${FOUNDLIMIT}"
else
     echo ""
fi
echo "Now running command :"
echo $ANSIBLE_COMMAND
echo ""

confirm && eval time $ANSIBLE_COMMAND

