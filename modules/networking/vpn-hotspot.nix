{ config, pkgs, lib, ... }:

# VPN-routed WiFi hotspot.
#
# Broadcasts a dedicated WiFi network on the laptop WiFi card (wlo1) that the
# phone connects to; ONLY the hotspot clients' traffic is tunneled through
# NordVPN (NordLynx / WireGuard), while the PC's own traffic keeps using the
# direct ethernet connection.
#
# Upstream internet for the PC must come from the ethernet cable (enp7s0) while
# the hotspot is up — a single WiFi radio can't reliably be a client and an
# access point at the same time.
#
# One-time prerequisite (NOT declarative — NordVPN does not publish WG configs):
#   1. Run the Nord client once, e.g.
#        nix run github:connerohnesorge/nordvpn-flake#nordvpn
#      then `nordvpn login` && `nordvpn connect`.
#   2. `sudo wg show nordlynx` → copy the interface private key, peer public key
#      and endpoint (<ip>:51820) into the placeholders below / the key file.
#   3. Write the private key to /etc/nixos/secrets/wg-nord.key (chmod 600, root).
#      secrets/ is gitignored — never commit it.

let
  # ---- Fill these in from `wg show nordlynx` (see header) -----------------
  serverPublicKey = "AQ+reNE4hk8UB2YY6NbwA6kaZCMrMPxKUzUK2+E2dxE=";  # cy40.nordvpn.com
  serverEndpoint  = "195.47.194.17:51820";                            # cy40.nordvpn.com
  nordlynxAddress = "10.5.0.2/32";   # NordLynx-assigned interface address
  # ---- Hotspot credentials (choose your own) -----------------------------
  ssid       = ".Winton.wg";
  passphrase = "ghbdtnWintonCy";  # min 8 chars
  # ------------------------------------------------------------------------

  apIface   = "wlo1";                # WiFi card used as the access point
  apSubnet  = "192.168.12.0/24";     # create_ap default subnet
  vpnTable  = 100;                   # dedicated routing table for tunneled clients

  hotspot = pkgs.writeShellApplication {
    name = "hotspot";
    runtimeInputs = with pkgs; [ linux-wifi-hotspot networkmanager systemd ];
    text = ''
      case "''${1:-}" in
        up)
          # Release the WiFi card from NetworkManager so it can run as an AP.
          sudo nmcli device set ${apIface} managed no
          # Bring up the tunnel + policy routing (table ${toString vpnTable}).
          sudo systemctl start wireguard-wg-nord
          # AP on ${apIface}, NAT'd out wg-nord. create_ap owns hostapd + dnsmasq
          # + MASQUERADE; our `ip rule` is what steers this subnet into the VPN.
          # --dhcp-dns pushes a public resolver so the phone's DNS is tunneled too.
          sudo create_ap --no-virt --dhcp-dns 1.1.1.1 \
            ${apIface} wg-nord "${ssid}" "${passphrase}"
          ;;
        down)
          sudo create_ap --stop ${apIface} || true
          sudo systemctl stop wireguard-wg-nord || true
          sudo nmcli device set ${apIface} managed yes
          ;;
        *)
          echo "usage: hotspot up|down" >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  # WireGuard tunnel to NordVPN. allowedIPsAsRoutes = false keeps it from
  # hijacking the host's default route; instead postSetup installs a default
  # route in a dedicated table and a policy rule so ONLY the hotspot subnet
  # is sent through the tunnel.
  networking.wireguard.interfaces.wg-nord = {
    ips = [ nordlynxAddress ];
    privateKeyFile = "/etc/nixos/secrets/wg-nord.key";
    allowedIPsAsRoutes = false;
    peers = [{
      publicKey = serverPublicKey;
      allowedIPs = [ "0.0.0.0/0" ];
      endpoint = serverEndpoint;
      persistentKeepalive = 25;
    }];
    postSetup = ''
      ${pkgs.iproute2}/bin/ip route replace default dev wg-nord table ${toString vpnTable}
      ${pkgs.iproute2}/bin/ip rule add from ${apSubnet} lookup ${toString vpnTable}
      # Accept the asymmetric return path: replies arrive on wg-nord but the main
      # table routes those source IPs via ethernet, so strict rp_filter would drop them.
      echo 2 > /proc/sys/net/ipv4/conf/wg-nord/rp_filter || true
      # Clamp TCP MSS to the tunnel's path MTU. Without this, the phone's full-size
      # (1500-byte) packets exceed WireGuard's ~1420 MTU and large flows (TLS/web)
      # silently stall — the classic "connected but no pages load" symptom.
      ${pkgs.iptables}/bin/iptables -t mangle -C FORWARD -o wg-nord -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null \
        || ${pkgs.iptables}/bin/iptables -t mangle -A FORWARD -o wg-nord -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    '';
    postShutdown = ''
      ${pkgs.iproute2}/bin/ip rule del from ${apSubnet} lookup ${toString vpnTable} || true
      ${pkgs.iptables}/bin/iptables -t mangle -D FORWARD -o wg-nord -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
    '';
  };

  # The toggle command owns the tunnel lifecycle — don't start it at boot.
  systemd.services.wireguard-wg-nord.wantedBy = lib.mkForce [ ];

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # Tunneled clients use asymmetric (policy) routing; don't let the firewall's
  # reverse-path check drop their return traffic.
  networking.firewall.checkReversePath = "loose";

  # Let hotspot clients reach the DHCP/DNS server running on the AP interface.
  networking.firewall.interfaces.${apIface} = {
    allowedUDPPorts = [ 53 67 ];
    allowedTCPPorts = [ 53 ];
  };

  # Non-interactive sudo for the toggle command (mirrors the nmcli rule in
  # configuration.nix). Kept here so this module is self-contained.
  security.sudo.extraRules = [{
    users = [ "bb99" ];
    commands = [
      { command = "${pkgs.linux-wifi-hotspot}/bin/create_ap *"; options = [ "NOPASSWD" ]; }
      { command = "${pkgs.systemd}/bin/systemctl start wireguard-wg-nord"; options = [ "NOPASSWD" ]; }
      { command = "${pkgs.systemd}/bin/systemctl stop wireguard-wg-nord"; options = [ "NOPASSWD" ]; }
      { command = "${pkgs.networkmanager}/bin/nmcli device set ${apIface} *"; options = [ "NOPASSWD" ]; }
    ];
  }];

  environment.systemPackages = [
    pkgs.linux-wifi-hotspot   # provides create_ap (hostapd + dnsmasq + NAT)
    hotspot                   # the `hotspot up|down` toggle command
  ];
}
