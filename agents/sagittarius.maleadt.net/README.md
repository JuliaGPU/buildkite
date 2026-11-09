# sagittarius.maleadt.net

The agent container is attached to a macvlan on a dedicated VLAN (VLAN 4,
192.168.4.0/24) instead of a podman bridge, so that jobs are not NATed through
the host onto its local network. The upstream gateway only lets that VLAN
reach the internet.

## Host setup

A VLAN interface without host addressing, managed by systemd-networkd:

```
# /etc/systemd/network/10-enp89s0.4.netdev
[NetDev]
Name=enp89s0.4
Kind=vlan

[VLAN]
Id=4
```

```
# /etc/systemd/network/10-enp89s0.4.network
[Match]
Name=enp89s0.4

[Link]
RequiredForOnline=carrier

[Network]
DHCP=no
LinkLocalAddressing=no
IPv6AcceptRA=no
ConfigureWithoutCarrier=yes
```

```
# /etc/systemd/network/wired.network.d/vlan4.conf
[Network]
VLAN=enp89s0.4
```

After `networkctl reload`, create the podman network the compose file uses:

```
podman network create -d macvlan -o parent=enp89s0.4 \
    --subnet 192.168.4.0/24 --gateway 192.168.4.1 julia
```

macvlan networks have no aardvark resolver, so the compose file sets the DNS
server explicitly. If the `julia` network is missing, `podman compose up`
fails instead of starting the agent on another network.

## Rollback

Revert the compose change, then:

```
podman network rm julia
rm /etc/systemd/network/10-enp89s0.4.{netdev,network} \
   /etc/systemd/network/wired.network.d/vlan4.conf
networkctl reload
ip link del enp89s0.4
```
