{ pkgs, vscode-extensions, ... }: {
  environment.systemPackages = with pkgs; [
    (vscode-with-extensions.override {
      vscodeExtensions = with vscode-extensions; [
        bbenoist.nix
        ms-vscode.cmake-tools
        # ms-vscode.cpptools
        ms-python.python
        vscode-icons-team.vscode-icons
        golang.go
      ];
    })
  ];
}
