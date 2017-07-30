# --                                                            # {{{1
#
# File        : ~/cfg/prompt.bash
# Maintainer  : Felix C. Stegerman <flx@obfusk.net>
# Date        : 2012-12-14
#
# Copyright   : Copyright (C) 2012  Felix C. Stegerman
# Licence     : GPLv2
#
# --                                                            # }}}1

# --                                                            # {{{1
#
# \u user, \h host, \w cwd, \j jobs, $? exitcode, \$ $|#
#
# colours:
#   between \[\033[ and m\]
#
#   black       0;30    dark gray     1;30
#   blue        0;34    light blue    1;34
#   green       0;32    light green   1;32
#   cyan        0;36    light cyan    1;36
#   red         0;31    light red     1;31
#   purple      0;35    light purple  1;35
#   brown       0;33    yellow        1;33
#   light gray  0;37    white         1;37
#
# --                                                            # }}}1
                                                                # {{{1
function __colour ()
{
  local red yll grn blu pur wht non

  red='\\\[\\033\[1;31m\\\]'
  yll='\\\[\\033\[1;33m\\\]'
  grn='\\\[\\033\[1;32m\\\]'
  blu='\\\[\\033\[1;34m\\\]'
  pur='\\\[\\033\[1;35m\\\]'
  wht='\\\[\\033\[1;37m\\\]'
  non='\\\[\\033\[0m\\\]'

  sed " s!RED!$red!g; s!YLL!$yll!g; s!GRN!$grn!g; s!BLU!$blu!g;
        s!PUR!$pur!g; s!WHT!$wht!g; s!NON!$non!g; "
}
                                                                # }}}1

function __git_ps1_flx ()
{
  local c="$1" n="$2" g="$( __git_ps1 %s )"
  [ -n "$g" ] && echo " ($c$g$n)"
}

# --

    GIT_PS1_SHOWDIRTYSTATE=yes
    GIT_PS1_SHOWSTASHSTATE=yes
GIT_PS1_SHOWUNTRACKEDFILES=yes
      GIT_PS1_SHOWUPSTREAM=auto

__prompt='[PUR\uNON@RED\hNON (WHT\jNONj WHT$?NON?) YLL\wNON'
__prompt+='$( __git_ps1_flx "BLU" "NON" )]\n\$ '

PS1="$( echo "$__prompt" | __colour )"

# vim: set tw=70 sw=2 sts=2 et fdm=marker :
