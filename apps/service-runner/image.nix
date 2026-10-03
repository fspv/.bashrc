{
  pkgs,
  serviceRunner,
  subordinateIdRanges,
}:
let
  passwd = pkgs.writeText "passwd" ''
    root:x:0:0:root:/root:${pkgs.bashInteractive}/bin/bash
    svc:x:1000:1000::/home/svc:${pkgs.bashInteractive}/bin/bash
    nobody:x:65534:65534:nobody:/:/bin/false
  '';

  group = pkgs.writeText "group" ''
    root:x:0:
    svc:x:1000:
    nogroup:x:65534:
  '';

  subordinateIds = pkgs.writeText "subordinate-ids" (
    pkgs.lib.concatMapStrings (range: "svc:${range}\n") subordinateIdRanges
  );

  policyJson = pkgs.writeText "policy.json" (
    builtins.toJSON {
      default = [ { type = "insecureAcceptAnything"; } ];
    }
  );

  registriesConf = pkgs.writeText "registries.conf" ''
    unqualified-search-registries = ["docker.io"]
    short-name-mode = "permissive"
  '';

  storageConf = pkgs.writeText "storage.conf" ''
    [storage]
    driver = "overlay"
    runroot = "/run/user/1000/containers"
    graphroot = "/home/svc/.local/share/containers/storage"
  '';

  containersConf = pkgs.writeText "containers.conf" ''
    [containers]
    log_driver = "k8s-file"

    [engine]
    cgroup_manager = "cgroupfs"
    events_logger = "file"

    [network]
    default_rootless_network_cmd = "slirp4netns"
  '';
in
pkgs.dockerTools.buildLayeredImage {
  name = "service-runner";
  tag = "latest";
  contents = with pkgs; [
    serviceRunner
    podman
    podman-compose
    conmon
    crun
    netavark
    aardvark-dns
    slirp4netns
    fuse-overlayfs
    iptables
    nftables
    su-exec
    shadow
    bashInteractive
    coreutils
    findutils
    cacert
    iproute2
    nettools
    iputils
    procps
    psmisc
    util-linux
    lsof
    strace
    tcpdump
    dnsutils
    curl
    netcat-openbsd
    less
    gnugrep
    gnused
    gawk
    jq
    htop
  ];
  fakeRootCommands = ''
    mkdir -p etc/containers usr/bin tmp var/tmp run/user/1000 home/svc/.config/containers home/svc/.local/share/containers/storage
    chmod 1777 tmp var/tmp
    cp ${passwd} etc/passwd
    cp ${group} etc/group
    cp ${subordinateIds} etc/subuid
    cp ${subordinateIds} etc/subgid
    cp ${policyJson} etc/containers/policy.json
    cp ${registriesConf} etc/containers/registries.conf
    cp ${registriesConf} home/svc/.config/containers/registries.conf
    cp ${storageConf} home/svc/.config/containers/storage.conf
    cp ${containersConf} home/svc/.config/containers/containers.conf
    cp ${pkgs.shadow}/bin/newuidmap ${pkgs.shadow}/bin/newgidmap usr/bin/
    chmod u+s usr/bin/newuidmap usr/bin/newgidmap
    chown -R 1000:1000 home/svc run/user/1000
  '';
  config = {
    Cmd = [ "/bin/service-runner" ];
    WorkingDir = "/service";
    Env = [
      "PATH=/usr/bin:/bin"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
    ];
  };
}
