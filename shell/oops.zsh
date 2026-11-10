# oops-shell — hook para zsh
[[ -n "${__OOPS_LOADED-}" ]] && return
typeset -g __OOPS_LOADED=1
typeset -g OOPS_HOME="${OOPS_HOME:-$HOME/.oops-shell}"
(( ${path[(Ie)$OOPS_HOME/bin]} )) || path+=("$OOPS_HOME/bin")

typeset -g __oops_armed=0

# Marca que um comando foi de fato executado (Enter vazio não dispara preexec).
__oops_preexec() { __oops_armed=1 }

__oops_precmd() {
  local st=$?
  if (( __oops_armed && st != 0 )); then
    "$OOPS_HOME/bin/oops" hook "$st"
  fi
  __oops_armed=0
  return $st
}

# Roda antes dos outros hooks para enxergar o $? original.
precmd_functions=(__oops_precmd ${precmd_functions[@]})
preexec_functions+=(__oops_preexec)
