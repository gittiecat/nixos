{ pkgs, ... }: {
	environment.systemPackages = with pkgs; [
		(vscode-with-extensions.override {
			vscodeExtensions = with vscode-extensions; [
				bbenoist.nix
				vscode-icons-team.vscode-icons
				ms-vscode.cmake-tools
				ms-vscode.cpptools
				golang.go
			];
		})
	];
}