#compdef termeric

_termeric() {
    local -a commands
    commands=(
        'install:Install termeric to current shell'
        'uninstall:Remove termeric from shell config'
        'update:Pull latest version and reinstall'
        'config:Open config in $EDITOR'
        'status:Show current settings and diagnostics'
        'font:Install Meslo Nerd Font'
        'doctor:Check system compatibility'
        'version:Show version'
        'help:Show help message'
    )

    _arguments -C \
        '1:command:->command' \
        '*::arg:->args'

    case $state in
        command)
            _describe 'command' commands
            ;;
        args)
            case $words[1] in
                install)
                    _arguments \
                        '--font[Install Meslo Nerd Font]' \
                        '--help[Show help]'
                    ;;
                *)
                    _arguments \
                        '--help[Show help]'
                    ;;
            esac
            ;;
    esac
}

_termeric "$@"
