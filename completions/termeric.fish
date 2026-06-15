# termeric fish completions

complete -c termeric -f

# Subcommands
complete -c termeric -n __fish_use_subcommand -a install -d 'Install termeric to current shell'
complete -c termeric -n __fish_use_subcommand -a uninstall -d 'Remove termeric from shell config'
complete -c termeric -n __fish_use_subcommand -a update -d 'Pull latest version and reinstall'
complete -c termeric -n __fish_use_subcommand -a config -d 'Open config in \$EDITOR'
complete -c termeric -n __fish_use_subcommand -a status -d 'Show current settings and diagnostics'
complete -c termeric -n __fish_use_subcommand -a font -d 'Install Meslo Nerd Font'
complete -c termeric -n __fish_use_subcommand -a doctor -d 'Check system compatibility'
complete -c termeric -n __fish_use_subcommand -a ai -d 'AI agent commands (agent/config/doctor)'
complete -c termeric -n __fish_use_subcommand -a version -d 'Show version'
complete -c termeric -n __fish_use_subcommand -a help -d 'Show help message'

# install options
complete -c termeric -n '__fish_seen_subcommand_from install' -l font -d 'Install Meslo Nerd Font'
complete -c termeric -n '__fish_seen_subcommand_from install' -l help -d 'Show help'

# Generic help
complete -c termeric -n '__fish_seen_subcommand_from uninstall update config status font doctor version' -l help -d 'Show help'
