class Termeric < Formula
  desc "Golden prompts for your terminal"
  homepage "https://github.com/modib/termeric"
  url "https://github.com/modib/termeric/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
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

        GIT_COLORS=on        Powerline segments (default: on)
        PROMPT_EXIT_CODE=on  Exit indicator (default: on)
        PROMPT_CMD_TIME=on   Command duration (default: off)
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/termeric version")
    assert_match "termeric", shell_output("#{bin}/termeric help")
  end
end
