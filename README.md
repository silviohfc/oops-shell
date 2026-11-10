# 🔊 oops-shell

Toca um efeito sonoro quando você digita um comando errado no terminal. Vem com o som **faah** por padrão.

Funciona em **bash** (3.2+), **zsh** e **fish**, no macOS e no Linux.

## Instalação

```bash
./install.sh
```

O instalador detecta o shell que você está usando, pergunta se deve instalar para ele e depois oferece instalar também para os outros shells encontrados no sistema.

Opções para uso sem perguntas:

```bash
./install.sh --shell zsh,fish   # shells específicos
./install.sh --all              # todos os shells suportados encontrados
./install.sh --yes              # só o shell detectado
```

Depois de instalar, abra um novo terminal (ou rode `exec $SHELL`).

## Uso

```bash
oops status          # configuração atual
oops test            # toca o som atual
oops list            # sons disponíveis
oops sound faah      # escolhe o som
oops mode notfound   # toca só quando o comando não existe (padrão)
oops mode error      # toca em qualquer comando que falhar
oops volume 0.5      # volume de 0.0 a 1.0 (afplay / pw-play)
oops off | oops on   # desliga / liga
```

Por padrão o som toca para "comando não encontrado" (código 127) e "não executável" (126). No modo `error` ele toca em qualquer código diferente de zero, exceto interrupções por sinal, como Ctrl+C.

### Adicionando sons

Coloque arquivos `.wav`, `.mp3`, `.aiff`, `.ogg` ou `.m4a` em `~/.oops-shell/sounds/` e selecione com `oops sound <nome>` (o nome do arquivo sem a extensão).

## Como funciona

- `install.sh` copia tudo para `~/.oops-shell` e adiciona um bloco marcado (`# >>> oops-shell >>>`) no `~/.zshrc` / `~/.bashrc` (e `~/.bash_profile` no macOS). No fish ele cria `~/.config/fish/conf.d/oops-shell.fish`. Reinstalar substitui o bloco em vez de duplicá-lo e mantém a sua configuração.
- Cada shell tem um hook pequeno (`shell/oops.*`) que roda depois de cada comando e repassa o código de saída para `bin/oops hook`. Um Enter vazio não dispara o som.
- `bin/oops` é um script POSIX que lê `~/.oops-shell/config` e toca o som em segundo plano com o player disponível: `afplay`, `paplay`, `pw-play`, `aplay`, `ffplay` ou `mpv`.

## Desinstalação

```bash
oops uninstall
```

Ou rode `./uninstall.sh` a partir da pasta do projeto.
