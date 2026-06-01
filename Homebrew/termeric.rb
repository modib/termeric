class Termeric < Formula
  desc "Golden prompts for your terminal"
  homepage "https://modib.github.io/termeric/"
  url "https://github.com/modib/termeric/archive/refs/tags/v1.2.0.tar.gz"
  sha256 "b29cc17b619e2edf83be219b2172ce6868c7c6f6b24b2deabc252269e49d242c"
  license "MIT"
  head "https://github.com/modib/termeric.git", branch: "main"

  depends_on "bash"
  depends_on "zsh"

  def install
    # Install shell configs
    pkgshare.install "termeric_bash", "termeric_zsh", "termeric_fish"

    # Install CLI
    bin.install "bin/termeric"

    # Install completions
    bash_completion.install "completions/termeric.bash" => "termeric"
    zsh_completion.install "completions/termeric.zsh" => "_termeric"
    fish_completion.install "completions/termeric.fish" => "termeric.fish"
  end

  def caveats
    <<~EOS
      To activate termeric, run:

        termeric install

      Or manually add to your shell config:

        bash (~/.bashrc):
          if [ -f #{pkgshare}/termeric_bash ]; then
              . #{pkgshare}/termeric_bash
          fi

        zsh (~/.zshrc):
          if [ -f #{pkgshare}/termeric_zsh ]; then
              . #{pkgshare}/termeric_zsh
          fi

        fish (~/.config/fish/config.fish):
          source #{pkgshare}/termeric_fish

      For powerline mode (recommended):

        termeric font

      Configuration (set before sourcing):

        PROMPT_COLOR=on        Master color switch: on (default) or off
        PROMPT_SHOW_USER=on    Show user@host segment (default: on)
        PROMPT_SHOW_EXIT=on    Show exit code on failure (default: on)
        PROMPT_SHOW_DIR=on     Show directory path (default: on)
        PROMPT_SHOW_SSH=on     Show SSH indicator (default: on)
        PROMPT_SHOW_TIME=off   Show command duration (default: off)
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/termeric version")
    assert_match "termeric", shell_output("#{bin}/termeric help")
  end
end
