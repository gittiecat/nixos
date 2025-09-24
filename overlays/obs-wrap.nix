self: super:
{
  obs-studio = super.obs-studio.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      wrapProgram $out/bin/obs \
        --set LD_LIBRARY_PATH "/run/opengl-driver/lib:/run/opengl-driver-32/lib:$LD_LIBRARY_PATH"
    '';
  });
}