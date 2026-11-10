# oops-shell — hook para bash (compatível com bash 3.2+)
[[ -n "${__OOPS_LOADED-}" ]] && return
[[ $- == *i* ]] || return
__OOPS_LOADED=1
OOPS_HOME="${OOPS_HOME:-$HOME/.oops-shell}"
case ":$PATH:" in *":$OOPS_HOME/bin:"*) ;; *) PATH="$PATH:$OOPS_HOME/bin" ;; esac

# Número do comando atual, usado para ignorar Enter vazio (que mantém o $? anterior).
if ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4))); then
  eval '__oops_cmdnum() { local p="\\#"; __oops_n=${p@P}; }'
else
  __oops_cmdnum() { read -r __oops_n _ <<<"$(HISTTIMEFORMAT= builtin history 1)"; }
fi

__oops_last=
__oops_prompt() {
  local st=$?
  __oops_cmdnum
  if [[ -n $__oops_last && $__oops_n != "$__oops_last" && $st -ne 0 ]]; then
    "$OOPS_HOME/bin/oops" hook "$st"
  fi
  __oops_last=$__oops_n
  return $st
}

# Roda antes dos outros comandos do prompt para enxergar o $? original.
PROMPT_COMMAND="__oops_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
