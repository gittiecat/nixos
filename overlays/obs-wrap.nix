self: super:
{
  obs-studio = super.obs-studio.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      wrapProgram $out/bin/obs \
        --set LD_LIBRARY_PATH "/run/opengl-driver/lib:/run/opengl-driver-32/lib:$LD_LIBRARY_PATH"
    '';
  });
}

# self: super:
# {
#   obs-studio = super.obs-studio.overrideAttrs (final: prev: {
#     env = (prev.env or {}) // {
#       NIX_CFLAGS_COMPILE =
#         ((prev.env or {}).NIX_CFLAGS_COMPILE or "")
#         + " -fno-lto -Wno-error=int-conversion -Wno-error=incompatible-pointer-types -Wno-error=implicit-function-declaration";
#       NIX_LDFLAGS =
#         ((prev.env or {}).NIX_LDFLAGS or "")
#         + " -fno-lto";
#     };

#     postInstall = (prev.postInstall or "") + ''
#       wrapProgram $out/bin/obs \
#         --set LD_LIBRARY_PATH "/run/opengl-driver/lib:/run/opengl-driver-32/lib:$LD_LIBRARY_PATH"
#     '';
#   });
# }
