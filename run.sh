#!/bin/bash

usage()
{
cat << EOF

Playbook Runner

This shell script requires several options to be supplied in order to run specific playbooks.

Syntax :
$0 -v -p <playbook> -t <target> -l <limittoserver(s)> -o <playbook tag(s)> -a <gpg auth>

<playbook> and <target> are mandatory.

Limiting a play to certain servers         (see hosts.* files for group and server names)
Examples :
$0 -p site -t live -l server1           (run only on server1)
$0 -p site -t live -l server1:server2   (run only on server1 and server2)
$0 -p site -t live -l servers           (run only on servers in the [servers] group)


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

PLAYBOOK=
TARGET=
PLAYBOOK_OPTIONS=
VERBOSE=
LIMITTO=
GPGAUTH=
SKIPCLONE=yes
while getopts "hp:t:o:l:a:vs" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         p)
             PLAYBOOK=$OPTARG
             ;;
         t)
             TARGET=$OPTARG
             ;;
         o)
             PLAYBOOK_OPTIONS=$OPTARG
             ;;
         l)
             LIMITTO=$OPTARG
             ;;
         a)
             GPGAUTH=$OPTARG
             ;;
         v)
             VERBOSE=vvv
             ;;
         s)
             SKIPCLONE=
             ;;
         ?)
             echo "invalid usage"
             echo "$0 $*"
             echo ""
             usage
             exit
             ;;
     esac
done

# We need a playbook and a target, always
if [[ -z $PLAYBOOK ]] || [[ -z $TARGET ]]
then
     usage
     exit 1
fi

# Check if playbook file exists
if [[ ! -f playbooks/$PLAYBOOK.yml ]]
then
     echo "Playbook playbook.$PLAYBOOK.yml does not exist!"
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

# Check if apptag(s) exists so we don't go thru an entire playbook without action
FOUNDTAGS=
if [[ ! -z $PLAYBOOK_OPTIONS ]]
then
     checktags=$(echo $PLAYBOOK_OPTIONS | tr "," "\n")
     for tag in $checktags
     do
          if [[ ! $(grep "$tag" playbooks/$PLAYBOOK.yml | grep tags:) ]]
          then
               # not found
               echo "$tag is not specified as a tag in playbook.$PLAYBOOK.yml!"
               exit 1
          else
               FOUNDTAGS+="`grep "$tag" playbooks/$PLAYBOOK.yml | grep tags:`\n"
          fi
     done
     if [[ -z $FOUNDTAGS ]]
     then
          # safeguard, should never happen.
          echo "Did not find any specified apptag."
          exit 1
     fi
fi

# When limiting, check to ensure the server or group actually is defined in the hostfile
# so we don't go thru an entire playbook without action
FOUNDLIMIT=
if [[ ! -z $LIMITTO ]]
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
ANSIBLE_COMMAND="ansible-playbook -v${VERBOSE} -i inventories/hosts.${TARGET} playbooks/${PLAYBOOK}.yml --become"
if [[ ! $TARGET == "devops-CnC" ]]
then
     if [[ -z $GPGAUTH ]]
     then
          if [[ ! $TARGET == "vm" ]]
          then
               ANSIBLE_COMMAND+=" --ask-become-pass"
          else
               ANSIBLE_COMMAND+=' --extra-vars "ansible_become_pass=foo"'
          fi
     else
          ANSIBLE_COMMAND+=' --extra-vars "ansible_become_pass=`gpg --output - --decrypt '
          ANSIBLE_COMMAND+="$GPGAUTH"
          ANSIBLE_COMMAND+='`"'
     fi
fi
if [[ ! -z $LIMITTO ]]
then
     ANSIBLE_COMMAND+=" --limit ${LIMITTO//[[:space:]]}"
fi
if [[ ! -z $PLAYBOOK_OPTIONS ]]
then
     if [[ -z $SKIPCLONE ]]
     then
          ANSIBLE_COMMAND+=" --tags gather,init,${PLAYBOOK_OPTIONS//[[:space:]]}"
     else
          ANSIBLE_COMMAND+=" --tags gather,${PLAYBOOK_OPTIONS//[[:space:]]}"
     fi
fi

echo ""
echo "=================================="
echo "$0 $*"
echo "=================================="
echo "VERBOSE          == $VERBOSE"
echo "PLAYBOOK         == $PLAYBOOK"
echo "TARGET           == $TARGET"
echo "LIMITTO          == $LIMITTO"
echo "GPGAUTH          == $GPGAUTH"
echo "PLAYBOOK_OPTIONS == $PLAYBOOK_OPTIONS"
echo "SKIPCLONE        == $SKIPCLONE"
if [[ ! -z $FOUNDTAGS ]]
then
     echo ""
     echo "Found the following tags :"
     echo -e "${FOUNDTAGS}"
else
     echo ""
fi
if [[ ! -z $FOUNDLIMIT ]]
then
     echo "Found the following server(s) or group(s) to limit too :"
     echo -e "${FOUNDLIMIT}"
else
     echo ""
fi
echo "Now running playbook command :"
echo $ANSIBLE_COMMAND
echo ""

confirm && eval time $ANSIBLE_COMMAND

