{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
  buildFHSEnv,
  writeShellScript,
  python3,
  curl,
  nix,
}:
let
  source = builtins.fromJSON (builtins.readFile ./source.json);
  unpacked = stdenvNoCC.mkDerivation {
    pname = "popo-unpacked";
    inherit (source) version;
    src = fetchurl { inherit (source) url hash; };
    nativeBuildInputs = [ dpkg ];
    dontUnpack = true;
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      dpkg-deb -x "$src" "$out"
      test "$(cat "$out/opt/apps/popo/files/version")" = "${source.version}"
      # Use system C++ runtime, matching upstream postinst.
      find "$out/opt" -name 'libstdc++.so.*' -delete
      runHook postInstall
    '';
  };
in
buildFHSEnv {
  pname = "popo";
  inherit (source) version;
  targetPkgs =
    pkgs: with pkgs; [
      alsa-lib
      at-spi2-core
      cairo
      cups
      dbus
      expat
      fontconfig
      freetype
      gdk-pixbuf
      glib
      gmp
      gtk3
      krb5
      lame
      libGL
      libcaca
      libdrm
      libgbm
      libjack2
      libjpeg
      (lib.getLib libjpeg8)
      libogg
      libpng
      libpulseaudio
      librsvg
      # POPO requires the pre-1.2 Theora ABI.
      (libtheora.overrideAttrs (old: {
        version = "1.1.1";
        nativeBuildInputs = lib.remove autoreconfHook old.nativeBuildInputs;
        src = fetchurl {
          url = "https://downloads.xiph.org/releases/theora/libtheora-1.1.1.tar.xz";
          hash = "sha256-822kCZR6orPcxq8KjC4xRLwZ2y7VR9ZOkXHFnGZWHGE=";
        };
      }))
      libvorbis
      libwebp
      libx11
      libxcb
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxft
      libxi
      libxinerama
      libxkbcommon
      libxkbfile
      libxrandr
      libxrender
      libxshmfence
      libxtst
      ncurses
      nspr
      nss
      numactl
      openjpeg
      libopus
      pango
      pixman
      speex
      stdenv.cc.cc.lib
      systemdLibs
      twolame
      wavpack
      wayland
      libxcb-util
      libxcb-cursor
      libxcb-image
      libxcb-keysyms
      libxcb-render-util
      libxcb-wm
      xkeyboard-config
      xz
      zlib
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      coreutils
      gnugrep
      gawk
      procps
      xdg-utils
    ];
  multiPkgs = null;
  extraBuildCommands = ''
    ln -s ${unpacked}/opt "$out/opt"
  '';
  runScript = writeShellScript "popo-start" ''
    cd /opt/apps/popo/files/${source.version}
    export LD_LIBRARY_PATH="$PWD:/usr/lib"
    export QT_PLUGIN_PATH="$PWD/plugins"
    export QML2_IMPORT_PATH="$PWD"
    export QT_QPA_PLATFORM=xcb
    unset QT_QPA_PLATFORM_PLUGIN_PATH
    exec ./popo "$@"
  '';
  extraInstallCommands = ''
    mkdir -p "$out/share/applications" "$out/share/pixmaps"
    cp ${unpacked}/opt/apps/popo/entries/applications/popo.desktop "$out/share/applications/"
    cp ${unpacked}/opt/apps/popo/files/logo.ico "$out/share/pixmaps/popo.ico"
    substituteInPlace "$out/share/applications/popo.desktop" \
      --replace-fail /opt/apps/popo/files/Elevator.sh "$out/bin/popo" \
      --replace-fail /opt/apps/popo/files/logo.ico "$out/share/pixmaps/popo.ico" \
      --replace-fail 'Categories=Chat;' 'Categories=Network;InstantMessaging;'
  '';
  passthru = {
    inherit (unpacked) src;
    updateScript = writeShellScript "update-popo" ''
      export PATH=${
        lib.makeBinPath [
          python3
          curl
          nix
          dpkg
        ]
      }:$PATH
      exec python3 ${./update.py}
    '';
  };
  meta = {
    description = "NetEase POPO messaging and collaboration client";
    homepage = "https://popo.netease.com/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "popo";
  };
}
