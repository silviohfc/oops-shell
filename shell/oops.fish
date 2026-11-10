# oops-shell — hook para fish
if status is-interactive; and not set -q __OOPS_LOADED
    set -g __OOPS_LOADED 1
    set -q OOPS_HOME; or set -g OOPS_HOME $HOME/.oops-shell
    contains -- $OOPS_HOME/bin $PATH; or set -gx PATH $PATH $OOPS_HOME/bin

    # fish_postexec só dispara quando um comando é executado (Enter vazio não conta).
    function __oops_postexec --on-event fish_postexec
        set -l st $status
        test $st -ne 0; and $OOPS_HOME/bin/oops hook $st
    end
end
