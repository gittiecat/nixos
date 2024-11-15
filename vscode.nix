{ pkgs, ... }: {
	environment.systemPackages = with pkgs; [
		(vscode-with-extensions.override {
			vscodeExtensions = with vscode-extensions; [
				bbenoist.nix
				ms-python.python
				vscode-icons-team.vscode-icons
			];
		})
	];
}