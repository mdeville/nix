{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  glib,
  libxkbcommon,
  fontconfig,
  freetype,
  libcap_ng,
  dbus,
  zlib,
  brotli,
  libnl,
  libGL,
  libglvnd,
  libdrm,
  wayland,
  xorg,
  iproute2,
  iptables,
  systemd,
  procps,
  psmisc,
}:
stdenv.mkDerivation {
  pname = "expressvpn";
  version = "14.1.0.13058";

  src = fetchurl {
    url = "https://www.expressvpn.works/clients/linux/expressvpn-linux-universal-14.1.0.13058_release.run";
    hash = "sha256-E4AV8ZibgpFLE7xzFOfHD9gNSxSr7A1IH/uPIum6bOg=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    glib
    libxkbcommon
    fontconfig
    freetype
    libcap_ng
    dbus
    zlib
    brotli
    libnl
    libGL
    libglvnd
    libdrm
    wayland
    xorg.libX11
    xorg.libxcb
    xorg.libSM
    xorg.libICE
    xorg.libXext
    xorg.xcbutilcursor
    xorg.libxkbfile
  ];

  # ExpressVPN ships QML plugins for Qt modules it never imports at runtime
  # (Qt.labs.*, QtQuick.VirtualKeyboard, QtQuick.Particles, QtQml.StateMachine,
  # QtQml.XmlListModel, QtQuick.LocalStorage, Qt-Wayland EGL/KMS integrations,
  # etc.). Their backing Qt libraries are not bundled in the .run, and we do
  # not want to mix them with nixpkgs Qt 6.x because the bundle is Qt 6.5.x.
  # Tell autoPatchelfHook to ignore those specific missing deps.
  autoPatchelfIgnoreMissingDeps = [
    "libQt6StateMachineQml.so.6"
    "libQt6StateMachine.so.6"
    "libQt6QmlXmlListModel.so.6"
    "libQt6LabsAnimation.so.6"
    "libQt6LabsFolderListModel.so.6"
    "libQt6LabsWavefrontMesh.so.6"
    "libQt6LabsSharedImage.so.6"
    "libQt6LabsSettings.so.6"
    "libQt6LabsQmlModels.so.6"
    "libQt6Bodymovin.so.6"
    "libQt6QuickTest.so.6"
    "libQt6Test.so.6"
    "libQt6QuickTimeline.so.6"
    "libQt6QuickParticles.so.6"
    "libQt6VirtualKeyboard.so.6"
    "libQt6QmlLocalStorage.so.6"
    "libQt6Sql.so.6"
    "libQt6WlShellIntegration.so.6"
    "libQt6EglFsKmsSupport.so.6"
    "libQt6EglFSDeviceIntegration.so.6"
  ];

  unpackPhase = ''
    runHook preUnpack
    bash "$src" --noexec --accept --target ./extract
    cd "./extract/${if stdenv.hostPlatform.isAarch64 then "arm64" else "x64"}"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"/{bin,lib,plugins,qml,share,share/applications,share/pixmaps}
    cp -r expressvpnfiles/bin/* "$out/bin/"
    cp -r expressvpnfiles/lib/* "$out/lib/"
    cp -r expressvpnfiles/plugins/* "$out/plugins/"
    cp -r expressvpnfiles/qml/* "$out/qml/"
    cp -r expressvpnfiles/share/* "$out/share/"

    install -m644 installfiles/app-icon.png "$out/share/pixmaps/expressvpn.png"

    substituteInPlace "$out/bin/qt.conf" \
      --replace-fail /opt/expressvpn "$out"

    substituteInPlace "$out/bin/openvpn-updown.sh" \
      --replace-fail /opt/expressvpn/var /var/lib/expressvpn

    ln -s expressvpn-daemon "$out/bin/expressvpnd"
    ln -s expressvpnctl "$out/bin/expressvpn"
    runHook postInstall
  '';

  postFixup =
    let
      rtPath = lib.makeBinPath [
        iproute2
        iptables
        systemd
        procps
        psmisc
      ];
    in
    ''
      for bin in expressvpn-daemon expressvpn-client expressvpnctl \
                 expressvpn-support-tool support-tool-launcher browser_helper; do
        wrapProgram "$out/bin/$bin" --prefix PATH : "${rtPath}"
      done
    '';

  desktopItems = [
    (makeDesktopItem {
      name = "expressvpn";
      exec = "expressvpn-client %u";
      icon = "expressvpn";
      desktopName = "ExpressVPN";
      comment = "ExpressVPN VPN client";
      categories = [ "Network" ];
      startupWMClass = "expressvpn-client";
      mimeTypes = [ "x-scheme-handler/expressvpn" ];
    })
  ];

  meta = {
    description = "CLI + GUI client for ExpressVPN (14.x)";
    homepage = "https://www.expressvpn.com";
    license = lib.licenses.unfree;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "expressvpn";
  };
}
