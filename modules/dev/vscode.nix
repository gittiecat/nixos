{ pkgs, marketplaceExtensions, ... }: {
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;  # or pkgs.vscodium for FOSS version
    extensions = with marketplaceExtensions; [
      bbenoist.nix
      ms-vscode.cmake-tools
      ms-python.python
      ms-python.vscode-pylance
      vscode-icons-team.vscode-icons
      golang.go
      anthropic.claude-code
    ];
  };
}