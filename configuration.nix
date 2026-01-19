{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  stockly,
  ...
}@args:

let
  plat = "linux-x64";
  archive_fmt = "tar.gz";
  myVsCode = pkgs.vscode.overrideAttrs (oldAttrs: rec {
    version = "1.106.3";
    src = builtins.fetchurl {
      name = "VSCode_${version}_${plat}.${archive_fmt}";
      url = "https://update.code.visualstudio.com/${version}/${plat}/stable";
      sha256 = "1kh7hrkyg30ralgidq3pk10061413046wfl10mi52sssjawygnsp";
    };
  });
  stockly-insomnia = (pkgs.callPackage "${stockly}/programs/insomnia.nix" { });
  stockly-jetbrains = (import "${stockly}/programs/jetbrains" args);
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024; # 16GB
    }
  ];

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
    };
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "stockly-871";
    nameservers = [
      "80.67.169.12"
      "80.67.169.40"
      "9.9.9.9"
    ];
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [
      # sshd
      22
      # nicotine-plus
      2234
      # for dev servers
      8080
    ];
  };

  time.timeZone = "Europe/Paris";

  i18n.defaultLocale = "en_IE.UTF-8";

  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };

  fonts.packages = with pkgs; [
    corefonts
    vista-fonts
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
  ];

  hardware = {
    graphics.enable = true;
    graphics.enable32Bit = true;
    bluetooth.enable = true;
    ckb-next = {
      enable = true;
      package = pkgs.ckb-next.overrideAttrs (old: {
        cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DUSE_DBUS_MENU=0" ];
      });
    };
    nvidia = {
      open = false;
      prime = {
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
      modesetting.enable = true;
      package = config.boot.kernelPackages.nvidiaPackages.beta;
    };
  };

  virtualisation.docker.enable = true;

  services = {
    blueman.enable = true;
    expressvpn.enable = true;
    libinput.enable = true;
    ollama = {
      enable = true;
      acceleration = "cuda";
      package = pkgs-unstable.ollama;
    };
    openssh.enable = true;
    pipewire = {
      enable = true;
      pulse.enable = true;
      jack.enable = true;
    };
    postgresql = {
      enable = true;
      enableTCPIP = true;
      authentication = pkgs.lib.mkOverride 10 ''
        #...
        #type database DBuser origin-address auth-method
        local all       all     trust
        # ipv4
        host  all      all     127.0.0.1/32   trust
        # ipv6
        host all       all     ::1/128        trust
      '';
    };
    printing = {
      enable = true;
      drivers = with pkgs; [ brlaser ];
    };
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
    xserver = {
      enable = true;
      videoDrivers = [ "nvidia" ];
      xkb.layout = "us";
      excludePackages = [ pkgs.xterm ];
    };
  };

  # Disable services on boot
  systemd.services = {
    ollama.wantedBy = lib.mkForce [ ];
    postgresql.wantedBy = lib.mkForce [ ];
  };

  users = {
    defaultUserShell = pkgs.zsh;
    users.mdeville = {
      isNormalUser = true;
      extraGroups = [
        "docker"
        "networkmanager"
        "wheel"
      ];
      packages = with pkgs; [
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGE+jfrb2lrlPhEnOmhe+5DjIu+/uLxGhwU3TPGCVB6j matthew@stockly.ai"
      ];
    };
  };

  programs = {
    _1password.enable = true;
    _1password-gui = {
      enable = true;
      polkitPolicyOwners = [ "mdeville" ];
    };
    dconf.enable = true;
    direnv.enable = true;
    firefox.enable = true;
    git = {
      enable = true;
      config = {
        core.pager = "delta";
        interactive.diffFilter = "delta --color-only";
        delta = {
          navigate = true;
          dark = true;
        };
        merge.conflictstyle = "zdiff3";
      };
    };
    neovim = {
      enable = true;
      defaultEditor = true;
    };
    starship.enable = true;
    steam.enable = true;
    zsh = {
      enable = true;
      histSize = 20000;
      enableCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
      shellAliases = {
        zed = "zeditor";
        open = "xdg-open";
      };
      ohMyZsh = {
        enable = true;
        plugins = [
          "git"
          "rust"
        ];
      };
    };
  };

  environment.gnome.excludePackages = with pkgs; [
    geary
    gnome-text-editor
    gnome-tour
  ];

  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    appimage-run
    audacity
    awscli2
    bat
    btop
    pkgs-unstable.code-cursor
    clojure
    stockly-jetbrains.datagrip
    pkgs-unstable.duckdb
    delta
    docker-compose
    expressvpn
    eza
    fastfetch
    fd
    filezilla
    gcc
    gimp
    pkgs-unstable.ghostty
    gnomeExtensions.appindicator
    gnumake
    gparted
    helvum
    stockly-insomnia
    jq
    lshw
    mixxx
    ncdu
    nicotine-plus
    nixd
    nixfmt
    nushell
    onlyoffice-desktopeditors
    openssl
    qbittorrent
    qemu
    rclone
    ripgrep
    slack
    supercollider
    myVsCode
    unciv
    ungoogled-chromium
    uv
    vcv-rack
    vim
    vlc
    wget
    #pkgs-unstable.zed-editor
    (python3.withPackages (
      python-pkgs: with python-pkgs; [
        jupyter
        jupyter-collaboration
        lxml
        notebook
        numpy
        matplotlib
        pandas
        psycopg
        requests
      ] ++ pandas.optional-dependencies.parquet
    ))
    zbar
    zrythm
  ];

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?
}
