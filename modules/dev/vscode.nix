{ pkgs, marketplaceExtensions, ... }: {
  # environment.systemPackages = [
  #   (pkgs.vscode-with-extensions.override {
  #     vscodeExtensions = [
        # marketplaceExtensions.bbenoist.nix
        # marketplaceExtensions.ms-vscode.cmake-tools
        # marketplaceExtensions.ms-python.python
        # marketplaceExtensions.ms-python.vscode-pylance
        # marketplaceExtensions.vscode-icons-team.vscode-icons
        # marketplaceExtensions.golang.go
  #     ];
  #   })
  # ];
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
    ];
  };
}