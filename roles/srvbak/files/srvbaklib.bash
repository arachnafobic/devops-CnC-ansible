#!/bin/bash

# --                                                            ; {{{1
#
# File        : srvbaklib.bash
# Maintainer  : Felix C. Stegerman <flx@obfusk.net>
# Date        : 2013-06-04
#
# Copyright   : Copyright (C) 2013  Felix C. Stegerman
# Licence     : GPLv2
#
# --
#
# NB: set -e, umask 0077.
#
# Uses: $date, $verbose, $dryrun; $base_dir, $keep_last; $gpg_opts,
# $gpg_key; $mongo_host, $mongo_passfile.
#
# Uses/Sets: $BAKTOGIT_REPO, $baktogit_items, $baktogit_keep_last;
# $data_dir__${data_dir_n}, $data_dir_n;
# $sensitive_data_dir__${sensitive_data_dir_n}, $sensitive_data_dir_n;
# $srvbak_status.
#
# --                                                            ; }}}1

export LC_COLLATE=C

# --

# Usage: die <msg(s)>
function die () { echo "$@" >&2; exit 1; }

# Usage: pipe_chk [<msg(s)>]
# Checks ${PIPESTATUS[@]} and dies if any are non-zero.
function pipe_chk ()
{                                                               # {{{1
  local ps=( "${PIPESTATUS[@]}" ) x
  for x in "${ps[@]}"; do
    [ "$x" -eq 0 ] || die 'non-zero PIPESTATUS' "$@"
  done
}                                                               # }}}1

# Usage: grep0 [<arg(s)>]
# Runs grep <arg(s)> but returns 0 if grep returned 0 or 1; and 1 if
# grep returned something else.  Thus, only returns non-zero if grep
# actually failed, not if it simply found nothing.
function grep0 () { grep "$@" || [ "$?" -eq 1 ]; }

# Usage: lock <file> [<target>]
# Creates lock file using ln -s; target defaults to $$; dies if ln
# fails and message doesn't contain 'exists'.
function lock ()
{                                                               # {{{1
  local x="$( ! LC_ALL=C ln -s "${2:-$$}" "$1" 2>&1 || echo OK )"
  if [ "$x" != OK ]; then
    [[ "$x" != *exists* ]] && die "locking failed -- $x"
    return 1
  fi
}                                                               # }}}1

# --

# Usage: dryrun
# Uses: $dryrun.
function dryrun () { [[ "$dryrun" == [Yy]* ]]; }

# Usage: mktemp_dry [<arg(s)>]
function mktemp_dry ()
{ if dryrun; then mktemp --dry-run "$@"; else mktemp "$@"; fi; }

# --

function run_hdr () { echo "==> $@"; }
function run_ftr () { echo; }

# Usage: run <cmd> <arg(s)>
function run () { run_hdr "$@"; dryrun || "$@"; run_ftr; }

# Usage: run_multi <cmd1-with-args> <cmd2-with-args> ...
function run_multi () { local x; for x in "$@"; do run $x; done; }

# --

# Usage: read_status
# Gets content of $base_dir/.var/status, or 'ok first-run' if it does
# not exist (yet); or 'ok dryrun' if dryrun.  See set_status.
function read_status ()
{                                                               # {{{1
  if dryrun; then
    echo 'ok dryrun'
  else
    local f="$base_dir"/.var/status
    if [ -e "$f" ]; then cat "$f"; else echo 'ok first-run'; fi
  fi
}                                                               # }}}1

# Usage: get_status
# Sets $srvbak_status using read_status.
function get_status () { srvbak_status="$( read_status )"; }

# Usage: set_status <info>
# Sets $srvbak_status and content of $base_dir/.var/status; should be
# one of: 'running $$', 'ok', or 'error'.
# See get_status, set_ok, set_running, set_error.
function set_status ()
{ srvbak_status="$1"; dryrun || echo "$1" > "$base_dir"/.var/status; }

function set_running  () { set_status "running $$"; }
function set_ok       () { set_status ok; }
function set_error    () { set_status error; }

# --

# Usage: baktogit_items <baktogit-arg(s)>
# Appends to $baktogit_items.
function baktogit_items () { baktogit_items+=( "$@" ); }

# Usage: data_dir <dir> [<arg(s)>]
# Sets $data_dir__${data_dir_n}, $data_dir_n.
function data_dir ()
{ eval 'data_dir__'"$data_dir_n"'=( "$@" )'; (( ++data_dir_n )); }

# Usage: sensitive_data_dir <dir> [<arg(s)>]
# Sets $sensitive_data_dir__${sensitive_data_dir_n},
# $sensitive_data_dir_n.
function sensitive_data_dir ()
{ eval 'sensitive_data_dir__'"$sensitive_data_dir_n"'=( "$@" )'
  (( ++sensitive_data_dir_n )); }

# --

# Usage: canonpath <path>
# No physical check on the filesystem, but a logical cleanup of a
# path.
# Uses perl.
function canonpath ()
{ perl -MFile::Spec -e 'print File::Spec->canonpath($ARGV[0])' "$1"; }

# Usage: hashpath <path>
# SHA1 hash of canonical path.
# Uses canonpath.
function hashpath ()
{ printf '%s' "$( canonpath "$1" )" | sha1sum | awk '{print $1}'
  pipe_chk; }

# --

# Usage: chown_to <user>
# Chowns $base_dir and, recursively, $base_dir/*/.
function chown_to ()
{                                                               # {{{1
  local user="$1" v="${verbose:+-c}"
  run chown       "$user" "$base_dir"
  run chown $v -R "$user" "$base_dir"/*/
}                                                               # }}}1

# Usage: chgrp_to <group>
# Chgrps $base_dir and, recursively, $base_dir/*/**.
function chgrp_to ()
{                                                               # {{{1
  local group="$1" v="${verbose:+-c}"
  run chgrp       "$group" "$base_dir"
  run chgrp $v -R "$group" "$base_dir"/*/
}                                                               # }}}1

# Usage: chmod_dirs <mode>
# Chmods $base_dir and dirs in $base_dir/*/.
function chmod_dirs ()
{                                                               # {{{1
  local mode="$1" v="${verbose:+-c}"
  run chmod "$mode" "$base_dir"
  run find "$base_dir"/*/ -type d -execdir chmod $v "$mode" {} \;
}                                                               # }}}1

# Usage: chmod_files <mode>
# Chmods files in $base_dir/*/.
function chmod_files ()
{                                                               # {{{1
  local mode="$1" v="${verbose:+-c}"
  run find "$base_dir"/*/ -type f -execdir chmod $v "$mode" {} \;
}                                                               # }}}1

# Usage: original_files_info <path> <to>
# Lists null-separated mode:owner:group:time:path of the original
# files in $path for all files in $to (e.g. for $to/some/file we get
# the info of $path/some/file).
# TODO: how best to handle failures?
function original_files_info ()
{                                                               # {{{1
  local path="$( canonpath "$1" )" to="$2" file
  find "$to" -printf '%P\0' | while IFS= read -r -d '' file; do
    stat --printf '%a:%U:%G:%.Y:%n\0' -- "$path/$file"
  done
}                                                               # }}}1

# --

# Usage: ls_backups <dir>
# Lists backups in <dir>; if dryrun and <dir> does not exist, prints a
# message to stderr instead of failing.
function ls_backups ()
{                                                               # {{{1
  local dir="$1"
  if dryrun && [ ! -e "$dir" ]; then
    echo "( ls_backups: DRY RUN and \`$dir' does not exist )" >&2
  else
    ls "$dir" | grep0 -E '^[0-9]{4}-'; pipe_chk
  fi
}                                                               # }}}1

# Usage: last_backup <dir>
# Uses ls_backups.
function last_backup () { ls_backups "$1" | tail -n 1; pipe_chk; }

# Usage: obsolete_backups <dir>
# Uses: $keep_last, ls_backups.
function obsolete_backups ()
{ ls_backups "$1" | head -n -"$keep_last"; pipe_chk; }

# Usage: cp_last_backup <dir> <path>
# Copies last backup in <dir> (if one exists) to <path> using hard
# links.
# NB: call before new backup (or dir creation)!
# Uses last_backup.
function cp_last_backup ()
{                                                               # {{{1
  local dir="$1" path="$2" ; local last="$( last_backup "$dir" )"
  if [ -n "$last" -a -e "$dir/$last" ]; then
    run cp -alT "$dir/$last" "$path"
  fi
}                                                               # }}}1

# Usage: rm_obsolete_backups <dir>
# NB: call after new backup!
# Uses $keep_last, obsolete_backups.
function rm_obsolete_backups ()
{                                                               # {{{1
  [ "$keep_last" == all ] && return
  local dir="$1" x
  for x in $( obsolete_backups "$dir" ); do
    run rm -fr "$dir/$x"
  done
}                                                               # }}}1

# --

# Usage: set_gpg
# Sets $gpg; uses $gpg_{opts,key}.
function set_gpg ()
{ gpg=( gpg "${gpg_opts[@]}" --batch -e -r "$gpg_key" ); }

# Usage: gpg_file <out> <in>
# Uses set_gpg.
function gpg_file ()                                            # {{{1
{
  local out="$1" in="$2" gpg ; set_gpg

  run_hdr "${gpg[@]} < $in > $out"
  dryrun || "${gpg[@]}" < "$in" > "$out"
  run_ftr
}                                                               # }}}1

# Usage: tar_gpg <out> <arg(s)>
# Uses set_gpg.
function tar_gpg ()                                             # {{{1
{
  local out="$1" ; shift
  local tar=( tar c --anchored "$@" ) gpg ; set_gpg

  run_hdr "${tar[@]} | ${gpg[@]} > $out"
  dryrun || { "${tar[@]}" | "${gpg[@]}" > "$out"; pipe_chk; }
  run_ftr
}                                                               # }}}1

# --

# Usage: process_mongo_passfile
# Uses $mongo_passfile; sets $mongo_auth__${db}__{user,pass}.
function process_mongo_passfile ()
{                                                               # {{{1
  [ -e "$mongo_passfile" ] || \
    die "bad mongo_passfile: $mongo_passfile"

  local oldifs="$IFS" db db_ user pass ; IFS=:
  while read -r db user pass; do
    [[ "$db" =~ ^[A-Za-z0-9_-]+$ ]] || die 'invalid mongo db name'
    db_="${db//-/__DASH__}"
    eval "mongo_auth__${db_}__user=\$user"
    eval "mongo_auth__${db_}__pass=\$pass"
  done < "$mongo_passfile" ; IFS="$oldifs"
}                                                               # }}}1

# --

# Usage: baktogit_tar_gpg <baktogit> <baktogit-item(s)>
# baktogit --> tar + gpg to $base_dir/baktogit/$date.tar.gpg.
# Uses $BAKTOGIT_REPO, $baktogit_keep_last.
function baktogit_tar_gpg ()
{                                                               # {{{1
  local baktogit="$1" ; shift
  [ -x "$baktogit" -o -x "$( which "$baktogit" )" ] || \
    die "bad baktogit: $baktogit"

  local keep_last="$baktogit_keep_last"   # dynamic override
  local       dir="$base_dir/baktogit"
  local        to="$dir/$date".tar.gpg

  run "$baktogit" "$@"
  run mkdir -p "$dir"
  tar_gpg "$to" $verbose "$BAKTOGIT_REPO"
  rm_obsolete_backups "$dir"
}                                                               # }}}1

# Usage: data_backup <path> [<opt(s)>]
# rsync directory to $base_dir/data/hash/$hash_of_path/$date,
# symlinked from $base_dir/data/path/$path.
# Writes $path to $base_dir/data/info/${hash_of_path}.path.
# Lists null-separated mode:owner:group:time:path of all files and
# directories to $base_dir/data/list/$hash_of_path/$date.
# Hard links last backup (if any); removes obsolete backups.
function data_backup ()
{                                                               # {{{1
  local path="$1" ; shift ; local hash="$( hashpath "$path" )"
  local       ddir="$base_dir"/data
  local    pdir_up="$ddir/path/$( dirname "$path" )"
  local       pdir="$ddir/path/$path"
  local       hdir="$ddir/hash/$hash"
  local       ldir="$ddir/list/$hash"
  local       idir="$ddir/info"
  local         to="$hdir/$date"
  local info_files="$ldir/$date"
  local  info_path="$idir/$hash.path"

  run mkdir -p "$pdir_up" "$hdir" "$ldir" "$idir"
  cp_last_backup "$hdir" "$to"

  [ -e "$exclude_from" ] || run rsync -a --no-owner --no-group --no-perms $verbose --delete "$@" "$path"/ "$to"/
  [ ! -e "$exclude_from" ] || run rsync -a --exclude-from="$exclude_from" --no-owner --no-group --no-perms $verbose --delete "$@" "$path"/ "$to"/

  [ -e "$pdir" ] || run ln -Ts "$hdir" "$pdir"

  run_hdr "[$path] > $info_path"
  dryrun || printf '%s' "$path" > "$info_path"
  run_ftr

  run_hdr "[find $to -> stat $path] > $info_files"
  dryrun || original_files_info "$path" "$to" > "$info_files"
  run_ftr

  rm_obsolete_backups "$hdir"
  rm_obsolete_backups "$ldir"
}                                                               # }}}1

# Usage: sensitive_data_backup <dir> [<opt(s)>]
# tar + gpg directory to
# $base_dir/sensitive_data/hash/$hash_of_path/$date.tar.gpg, symlinked
# from $base_dir/sensitive_data/path/$path.
# Writes $path to $base_dir/sensitive_data/info/${hash_of_path}.path.
# Removes obsolete backups.
function sensitive_data_backup ()
{                                                               # {{{1
  local path="$1" ; shift ; local hash="$( hashpath "$path" )"
  local      ddir="$base_dir"/sensitive_data
  local   pdir_up="$ddir/path/$( dirname "$path" )"
  local      pdir="$ddir/path/$path"
  local      hdir="$ddir/hash/$hash"
  local      idir="$ddir/info"
  local        to="$hdir/$date".tar.gpg
  local info_path="$idir/$hash.path"

  run mkdir -p "$pdir_up" "$hdir" "$idir"
  tar_gpg "$to" $verbose "$@" "$path"
  [ -e "$pdir" ] || run ln -Ts "$hdir" "$pdir"

  run_hdr "[$path] > $info_path"
  dryrun || printf '%s' "$path" > "$info_path"
  run_ftr

  rm_obsolete_backups "$hdir"
}                                                               # }}}1

# Usage: pg_backup <dbname> <dbuser>
# PostgreSQL dump to $base_dir/postgresql/$dbname/$date.sql.gpg.
# Removes obsolete backups.
# Uses $PG*.
function pg_backup ()
{                                                               # {{{1
  local dbname="$1" dbuser="$2"
  local dir="$base_dir/postgresql/$dbname"
  local temp="$( mktemp_dry )"
  local dump="$dir/$date".sql.gpg

  run mkdir -p "$dir"
  run pg_dump "$dbname" -f "$temp" -w -U "$dbuser"
  gpg_file "$dump" "$temp"
  run rm -f "$temp"
  rm_obsolete_backups "$dir"
}                                                               # }}}1

# Usage: mongo_backup <dbname>
# MongoDB dump to $base_dir/mongodb/$dbname/$date.tar.gpg.
# Removes obsolete backups.
# Uses $mongo_{host,auth__${dbname}__{user,pass}}.
function mongo_backup ()
{                                                               # {{{1
  [ -n "$mongo_host" ] || die 'empty $mongo_host'

  local dbname="$1" dbname_ user pass
  local dir="$base_dir/mongodb/$dbname"
  local temp="$( mktemp_dry -d )" ; local tsub="$dbname/$date"
  local dump="$dir/$date".tar.gpg

  [[ "$dbname" =~ ^[A-Za-z0-9_-]+$ ]] || die 'invalid mongo db name'
  dbname_="${dbname//-/__DASH__}"
  eval "user=\$mongo_auth__${dbname_}__user"
  eval "pass=\$mongo_auth__${dbname_}__pass"
  [ -n "$user" ] || die "empty \$mongo_auth__${dbname_}__user"
  [ -n "$pass" ] || die "empty \$mongo_auth__${dbname_}__pass"

  run mkdir -p "$dir" "$temp/$tsub"
  printf '%s\n' "$pass" | run mongodump -h "$mongo_host" \
    -d "$dbname" -u "$user" -p '' -o "$temp/$tsub"
  tar_gpg "$dump" $verbose -C "$temp" "$tsub"
  run rm -fr "$temp"
  rm_obsolete_backups "$dir"
}                                                               # }}}1

# Usage: dpkg_selections_backup
# dpkg selections dump to $base_dir/dpkg/$date.
# Removes obsolete backups.
function dpkg_selections_backup ()
{                                                               # {{{1
  local dir="$base_dir/dpkg" ; local dump="$dir/$date"

  run mkdir -p "$dir"
  run_hdr "dpkg --get-selections > $dump"
  dryrun || dpkg --get-selections > "$dump"
  run_ftr
  rm_obsolete_backups "$dir"
}                                                               # }}}1

# vim: set tw=70 sw=2 sts=2 et fdm=marker :
