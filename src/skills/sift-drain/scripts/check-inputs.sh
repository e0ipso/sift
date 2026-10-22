#!/usr/bin/env bash
# Internal evidence identity functions, sourced by check-evidence.sh.
check_hash() { git hash-object --stdin; }
check_hex() { od -An -tx1 | tr -d ' \n'; }
check_id() {
  case "$1" in ''|*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-]*|[._-]*) return 1 ;; esac
  [ "${#1}" -le 128 ]
}
check_relative() {
  case "$1" in ''|/*|../*|*/../*|*/..|..|./*|*/./*|*/.|*//*|*/) return 1 ;; esac
  case "$1" in *$'\n'*|*$'\t'*|*$'\r'*) return 1 ;; esac
}
check_env_name() {
  case "$1" in ''|[0-9]*|*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_]*) return 1 ;; esac
}
# Hash values, including a set/unset discriminator. Do not publish secrets.
check_environment() {
  local name value
  for name in "$@"; do
    check_env_name "$name" || return 1
    value=${!name-}
    [ -n "$value" ] || return 1
    printf 'env\t%s\t%s\n' "$name" "$(printf '%s\0' "$value" | check_hash)" || return 1
  done
}
check_mode() { LC_ALL=C ls -ld "$1" | awk '{print substr($1,1,10)}'; }
check_member() {
  local path=$1 encoded mode content target target_path target_mode parent
  encoded=$(printf '%s' "$path" | check_hex) || return 1
  mode=$(check_mode "$WORKTREE/$path") || return 1
  if [ -L "$WORKTREE/$path" ]; then
    command -v readlink >/dev/null 2>&1 || return 1
    # Directory links and broken links need project stamps; never omit their state.
    [ -f "$WORKTREE/$path" ] || return 1
    target_path=$(readlink "$WORKTREE/$path") || return 1
    case "$target_path" in /*) ;; *) target_path="$WORKTREE/$(dirname "$path")/$target_path" ;; esac
    [ ! -L "$target_path" ] || return 1
    parent=$(dirname "$target_path")
    while [ "$parent" != / ]; do
      [ ! -L "$parent" ] || return 1
      parent=$(dirname "$parent")
    done
    target=$(readlink "$WORKTREE/$path" | check_hex) || return 1
    target_mode=$(check_mode "$target_path") || return 1
    content=$(check_hash < "$WORKTREE/$path") || return 1
    printf 'link\t%s\t%s\t%s\t%s\t%s\n' "$encoded" "$mode" "$target" "$target_mode" "$content"
  elif [ -f "$WORKTREE/$path" ]; then
    content=$(check_hash < "$WORKTREE/$path") || return 1
    printf 'file\t%s\t%s\t%s\n' "$encoded" "$mode" "$content"
  elif [ -d "$WORKTREE/$path" ]; then
    printf 'directory\t%s\t%s\n' "$encoded" "$mode"
  else
    return 1
  fi
}
check_members() {
  local input path parent
  for input in "${INPUTS[@]}"; do
    check_relative "$input" || return 1
    # Refuse hidden directory-link traversal in a declared nested root.
    parent=$input
    while [ "$parent" != . ]; do
      parent=$(dirname "$parent")
      [ ! -L "$WORKTREE/$parent" ] || return 1
    done
    (cd "$WORKTREE" && find "./$input" -print0) |
      while IFS= read -r -d '' path; do
        check_member "${path#./}" || exit 1
      done || return 1
  done
}
# This is an observation, not a lock: writers must be quiescent at final gates.
# Failure still emits a diagnostic manifest; COMPLETE prevents reuse.
check_snapshot() {
  local declaration key value config_hash config_after platform cwd_actual
  local complete=true reason=complete seen_complete='' declared_stage='' declared_scope='' declared_cwd='' required=''
  local INPUTS=() ENVS=() DECLARED_ARGV=() platform_name='' declared_argv_hash
  config_hash=$(check_hash < "$SIFT/config/config.yaml") || config_hash=unavailable
  if declaration=$(SIFT_CHECK_ID="$CHECK_ID" LC_ALL=C awk -f "$HERE/check-declaration.awk" "$SIFT/config/config.yaml" 2>/dev/null); then
    while IFS=$'\t' read -r key value; do
      case "$key" in
        inputs) INPUTS+=("$value") ;; environment) ENVS+=("$value") ;;
        command) DECLARED_ARGV+=("$value") ;;
        complete) seen_complete=$value ;; stage) declared_stage=$value ;;
        scope) declared_scope=$value ;; cwd) declared_cwd=$value ;;
        required) required=$value ;; platform) platform_name=$value ;;
      esac
    done <<< "$declaration"
    declared_argv_hash=$(printf '%s\0' "${DECLARED_ARGV[@]}" | check_hash) || declared_argv_hash=unavailable
    if [ "$seen_complete" != true ] || [ "$required" != true ] ||
       [ "$STAGE" != "$declared_stage" ] || [ "$SCOPE" != "$declared_scope" ] ||
       [ "$LOGICAL_CWD" != "$declared_cwd" ] || [ "$ARGV_HASH" != "$declared_argv_hash" ]; then
      complete=false; reason=incomplete-declaration
    fi
  else
    complete=false; reason=incomplete-declaration
  fi
  printf 'identity-version\t1\ncheck\t%s\nstage\t%s\nscope\t%s\ncwd\t%s\nconfig\t%s\nargv\t%s\n' \
    "$CHECK_ID" "$STAGE" "$SCOPE" "$LOGICAL_CWD" "$config_hash" "$ARGV_HASH"
  printf 'umask\t%s\n' "$(umask)"
  if [ "$complete" = true ]; then
    if ! check_environment "$platform_name" "${ENVS[@]}"; then
      complete=false; reason=unavailable-environment
    fi
    if command -v uname >/dev/null 2>&1 && platform=$(uname -srm); then
      printf 'platform\t%s\n' "$(printf '%s' "$platform" | check_hex)"
    else
      complete=false; reason=unavailable-platform
    fi
    if ! check_members | LC_ALL=C sort -u; then
      complete=false; reason=unavailable-inputs
    fi
    cwd_actual=$(cd "$WORKTREE/$LOGICAL_CWD" && pwd -P) || cwd_actual=unavailable
    if { [ "$LOGICAL_CWD" = . ] && [ "$cwd_actual" != "$WORKTREE" ]; } ||
       { [ "$LOGICAL_CWD" != . ] && [ "$cwd_actual" != "$WORKTREE/$LOGICAL_CWD" ]; }; then
      complete=false; reason=unavailable-inputs
    fi
  fi
  config_after=$(check_hash < "$SIFT/config/config.yaml") || config_after=unavailable
  if [ "$config_hash" != "$config_after" ]; then complete=false; reason=unstable-inputs; fi
  printf 'complete\t%s\nreason\t%s\n' "$complete" "$reason"
}
check_field() { awk -F '\t' -v key="$2" '$1==key {print $2}' "$1"; }
check_text_field() { printf '%s\n' "$1" | awk -F '\t' -v key="$2" '$1==key {print $2}'; }
