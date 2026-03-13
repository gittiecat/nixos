{ pkgs, marketplaceExtensions, ... }: {
  environment.systemPackages = [
    (pkgs.vscode-with-extensions.override {
      vscodeExtensions = [
        marketplaceExtensions.bbenoist.nix
        marketplaceExtensions.ms-vscode.cmake-tools
        marketplaceExtensions.ms-python.python
        marketplaceExtensions.ms-python.vscode-pylance
        marketplaceExtensions.vscode-icons-team.vscode-icons
        marketplaceExtensions.golang.go
      ];
    })
  ];
}