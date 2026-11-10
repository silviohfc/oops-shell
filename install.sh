#!/usr/bin/env bash
# Instalador do oops-shell — toca um som quando você digita um comando errado.
# Compatível com bash 3.2+ (padrão do macOS).
set -euo pipefail

SUPPORTED_SHELLS="bash zsh fish"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OOPS_HOME="${OOPS_HOME:-$HOME/.oops-shell}"
MARK_START="# >>> oops-shell >>>"
MARK_END="# <<< oops-shell <<<"

ASSUME_YES=0
SELECTED=""

if [ -t 1 ]; then
  B=$'\033[1m' G=$'\033[32m' Y=$'\033[33m' R=$'\033[31m' D=$'\033[2m' N=$'\033[0m'
else
  B="" G="" Y="" R="" D="" N=""
fi

info() { printf '%s\n' "$*"; }
ok() { printf '%s✔%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s!%s %s\n' "$Y" "$N" "$*" >&2; }
die() { printf '%s✘%s %s\n' "$R" "$N" "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Uso: ./install.sh [opções]

Sem opções, detecta seu shell e pergunta para quais shells instalar.

Opções:
  -s, --shell LISTA   Instala só para os shells informados (ex.: zsh,fish)
  -a, --all           Instala para todos os shells suportados encontrados
  -y, --yes           Não pergunta nada: instala só para o shell detectado
  -h, --help          Mostra esta ajuda

Shells suportados: $SUPPORTED_SHELLS
EOF
}

# ---------- utilidades ----------

is_supported() { case " $SUPPORTED_SHELLS " in *" $1 "*) return 0 ;; esac; return 1; }
has_shell() { command -v "$1" >/dev/null 2>&1; }
contains() { case " $1 " in *" $2 "*) return 0 ;; esac; return 1; }
add_unique() { contains "$SELECTED" "$1" || SELECTED="${SELECTED:+$SELECTED }$1"; }

# Lê do terminal mesmo quando o script vem de um pipe (curl ... | bash).
ask() {
  local prompt=$1 default=$2 reply
  if [ "$ASSUME_YES" = 1 ] || ! { : </dev/tty; } 2>/dev/null; then
    REPLY=$default
    return
  fi
  printf '%s' "$prompt" >/dev/tty
  IFS= read -r reply </dev/tty || reply=""
  REPLY=${reply:-$default}
}

yes_no() { # yes_no "pergunta" s|n
  local hint="[s/N]"
  [ "$2" = s ] && hint="[S/n]"
  ask "$1 $hint " "$2"
  case $REPLY in [sSyY]*) return 0 ;; *) return 1 ;; esac
}

# Shell em uso: primeiro o processo que chamou o instalador, depois o $SHELL.
detect_shell() {
  local parent
  parent=$(ps -o comm= -p "$PPID" 2>/dev/null || true)
  parent=${parent##*/}
  parent=${parent#-}
  if is_supported "$parent"; then
    echo "$parent"
    return
  fi
  parent=${SHELL##*/}
  if is_supported "$parent"; then echo "$parent"; else echo ""; fi
}

rc_files_for() {
  case $1 in
    zsh) echo "${ZDOTDIR:-$HOME}/.zshrc" ;;
    bash)
      echo "$HOME/.bashrc"
      # No macOS o Terminal abre bash como login shell, que lê ~/.bash_profile.
      [ "$(uname -s)" = Darwin ] && echo "$HOME/.bash_profile"
      ;;
    fish) echo "${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/oops-shell.fish" ;;
  esac
  return 0
}

# Remove um bloco anterior do oops-shell (mantém permissões e symlinks do arquivo).
strip_block() {
  local file=$1 tmp
  [ -f "$file" ] || return 0
  grep -qF "$MARK_START" "$file" || return 0
  tmp=$(mktemp)
  # Remove também a linha em branco que o instalador adiciona antes do bloco.
  awk -v s="$MARK_START" -v e="$MARK_END" '
    $0 == s { skip = 1; blank = 0; next }
    $0 == e { skip = 0; next }
    skip { next }
    { if (blank) print ""; blank = 0 }
    $0 == "" { blank = 1; next }
    { print }
    END { if (blank) print "" }
  ' "$file" >"$tmp"
  cat "$tmp" >"$file"
  rm -f "$tmp"
}

# ---------- instalação ----------

install_files() {
  mkdir -p "$OOPS_HOME/bin" "$OOPS_HOME/shell" "$OOPS_HOME/sounds"
  cp "$SRC_DIR/bin/oops" "$OOPS_HOME/bin/oops"
  chmod +x "$OOPS_HOME/bin/oops"
  cp "$SRC_DIR"/shell/oops.* "$OOPS_HOME/shell/"
  cp "$SRC_DIR"/sounds/* "$OOPS_HOME/sounds/"
  cp "$SRC_DIR/uninstall.sh" "$OOPS_HOME/uninstall.sh"
  # Preserva a configuração do usuário em reinstalações.
  if [ ! -f "$OOPS_HOME/config" ]; then
    cat >"$OOPS_HOME/config" <<'EOF'
# Configuração do oops-shell (edite à vontade ou use o comando 'oops')
OOPS_ENABLED=1
OOPS_SOUND=faah
OOPS_MODE=notfound
OOPS_VOLUME=1
EOF
  fi
  ok "Arquivos copiados para $OOPS_HOME"
}

# Caminho gravado no rc: usa $HOME literal quando for o local padrão.
rc_home() {
  case $OOPS_HOME in
    "$HOME"/*) printf '%s' "\$HOME/${OOPS_HOME#"$HOME"/}" ;;
    *) printf '%s' "$OOPS_HOME" ;;
  esac
}

install_for() {
  local sh=$1 file home
  home=$(rc_home)
  if [ "$sh" = fish ]; then
    file=$(rc_files_for fish)
    mkdir -p "$(dirname "$file")"
    {
      echo "$MARK_START"
      echo "set -gx OOPS_HOME \"$home\""
      echo "source \"\$OOPS_HOME/shell/oops.fish\""
      echo "$MARK_END"
    } >"$file"
    ok "fish: $file"
    return
  fi
  for file in $(rc_files_for "$sh"); do
    [ -e "$file" ] || touch "$file"
    strip_block "$file"
    {
      echo ""
      echo "$MARK_START"
      echo "export OOPS_HOME=\"$home\""
      echo "[ -f \"\$OOPS_HOME/shell/oops.$sh\" ] && . \"\$OOPS_HOME/shell/oops.$sh\""
      echo "$MARK_END"
    } >>"$file"
    ok "$sh: $file"
  done
}

choose_shells() {
  local detected others="" sh i list choice
  detected=$(detect_shell)

  if [ -n "$detected" ]; then
    info "Shell detectado: ${B}$detected${N}"
    if yes_no "Instalar o oops-shell para ${B}$detected${N}?" s; then
      add_unique "$detected"
    fi
  else
    warn "Não consegui detectar um shell suportado (${SHELL:-desconhecido})."
  fi

  for sh in $SUPPORTED_SHELLS; do
    [ "$sh" = "$detected" ] && continue
    has_shell "$sh" && others="${others:+$others }$sh"
  done
  [ -z "$others" ] && return 0
  [ "$ASSUME_YES" = 1 ] && return 0

  echo ""
  info "Outros shells encontrados neste sistema: ${B}${others// /, }${N}"
  yes_no "Deseja instalar para outros shells também?" n || return 0

  i=0
  list=""
  for sh in $others; do
    i=$((i + 1))
    info "  $i) $sh"
    list="$list $sh"
  done
  ask "Digite os números separados por espaço (ou 't' para todos): " ""
  case $REPLY in
    t | T | todos | all) for sh in $others; do add_unique "$sh"; done ;;
    *)
      for choice in $REPLY; do
        case $choice in *[!0-9]* | '') warn "Opção inválida: $choice"; continue ;; esac
        set -- $list
        if [ "$choice" -ge 1 ] && [ "$choice" -le $# ]; then
          eval "add_unique \"\${$choice}\""
        else
          warn "Opção inválida: $choice"
        fi
      done
      ;;
  esac
}

main() {
  while [ $# -gt 0 ]; do
    case $1 in
      -s | --shell)
        [ $# -ge 2 ] || die "--shell precisa de uma lista (ex.: zsh,fish)"
        for sh in ${2//,/ }; do
          is_supported "$sh" || die "Shell não suportado: $sh (suportados: $SUPPORTED_SHELLS)"
          add_unique "$sh"
        done
        shift 2
        ;;
      -a | --all)
        for sh in $SUPPORTED_SHELLS; do has_shell "$sh" && add_unique "$sh"; done
        shift
        ;;
      -y | --yes) ASSUME_YES=1 && shift ;;
      -h | --help) usage && exit 0 ;;
      *) usage >&2 && exit 1 ;;
    esac
  done

  [ -f "$SRC_DIR/bin/oops" ] || die "Rode o instalador a partir da pasta do projeto."

  echo "${B}🔊 oops-shell${N} ${D}— sons para comandos errados${N}"
  echo ""

  [ -z "$SELECTED" ] && choose_shells
  [ -n "$SELECTED" ] || die "Nenhum shell selecionado. Nada foi instalado."

  echo ""
  install_files
  for sh in $SELECTED; do install_for "$sh"; done

  echo ""
  ok "${B}Instalado!${N} Abra um novo terminal (ou rode 'exec \$SHELL') e digite um comando errado."
  info "${D}Configure com: oops status | oops list | oops mode error | oops off${N}"
}

main "$@"
