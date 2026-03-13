{ pkgs, marketplaceExtensions, ... }: {
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (pkg.pname or "") [
    "vscode-extension-ms-python-vscode-pylance"
    "vscode-extension-ms-python-python"
    "vscode-extension-ms-vscode-cpptools"
  ];

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