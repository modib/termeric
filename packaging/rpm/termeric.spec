Name:           termeric
Version:        1.1.0
Release:        1%{?dist}
Summary:        Golden prompts for your terminal
License:        MIT
URL:            https://modib.github.io/termeric/
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
Requires:       bash zsh git

%description
AI-powered, modernized shell prompt for bash, zsh, and fish with
powerline segments, git status caching, and command timing.

%prep
%autosetup -n %{name}-%{version}

%install
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/share/%{name}
mkdir -p %{buildroot}/usr/share/bash-completion/completions
mkdir -p %{buildroot}/usr/share/zsh/site-functions
mkdir -p %{buildroot}/usr/share/fish/vendor_completions.d

install -m 755 bin/termeric %{buildroot}/usr/bin/termeric
install -m 644 termeric_bash %{buildroot}/usr/share/%{name}/
install -m 644 termeric_zsh %{buildroot}/usr/share/%{name}/
install -m 644 termeric_fish %{buildroot}/usr/share/%{name}/
install -m 644 completions/termeric.bash %{buildroot}/usr/share/bash-completion/completions/termeric
install -m 644 completions/termeric.zsh %{buildroot}/usr/share/zsh/site-functions/_termeric
install -m 644 completions/termeric.fish %{buildroot}/usr/share/fish/vendor_completions.d/termeric.fish

%post
echo ""
echo "termeric installed! Run 'termeric install' to activate."

%files
/usr/bin/termeric
/usr/share/%{name}/termeric_bash
/usr/share/%{name}/termeric_zsh
/usr/share/%{name}/termeric_fish
/usr/share/bash-completion/completions/termeric
/usr/share/zsh/site-functions/_termeric
/usr/share/fish/vendor_completions.d/termeric.fish
