#!/bin/sh
# Remove o oops-shell de todos os shells e apaga ~/.oops-shell.
set -eu

OOPS_HOME="${OOPS_HOME:-$HOME/.oops-shell}"
MARK_START="# >>> oops-shell >>>"
MARK_END="# <<< oops-shell <<<"

strip_block() {
  file=$1
  [ -f "$file" ] || return 0
  grep -qF "$MARK_START" "$file" || return 0
  tmp=$(mktemp)
  # Remove o bloco e a linha em branco que o instalador adiciona antes dele.
  awk -v s="$MARK_START" -v e="$MARK_END" '
    $0 == s { skip = 1; if (blank) blank = 0; next }
    $0 == e { skip = 0; next }
    skip { next }
    { if (blank) print ""; blank = 0 }
    $0 == "" { blank = 1; next }
    { print }
    END { if (blank) print "" }
  ' "$file" >"$tmp"
  cat "$tmp" >"$file"
  rm -f "$tmp"
  echo "✔ Removido de $file"
}

for f in "${ZDOTDIR:-$HOME}/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
  strip_block "$f"
done

fish_conf="${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/oops-shell.fish"
if [ -f "$fish_conf" ]; then
  rm -f "$fish_conf"
  echo "✔ Removido $fish_conf"
fi

case $OOPS_HOME in
  "$HOME"/?*) [ -d "$OOPS_HOME" ] && rm -rf "$OOPS_HOME" && echo "✔ Removido $OOPS_HOME" ;;
  *) echo "! OOPS_HOME fora da sua home ($OOPS_HOME); apague manualmente se quiser." >&2 ;;
esac

echo "oops-shell desinstalado. Abra um novo terminal para concluir."
