# Adding a DHCP server to my AD lab

I added the DHCP role to my domain controller (DC01) and moved my Windows 11 client from a static address to DHCP. A competing DHCP server on the VirtualBox host-only network got in the way, so most of this write-up is the troubleshooting.

## Environment

| Machine | Role | Addressing |
|---|---|---|
| DC01 (Windows Server 2022) | Domain controller, DNS, DHCP | Static `192.168.56.10` |
| Win 11 VM | Client | DHCP (host-only adapter) |
| Ubuntu VM | Domain-joined Linux client | Static `192.168.56.30` |

Each VM has a NAT adapter and a host-only adapter (`192.168.56.0/24`).

## What I did

1. **Disabled VirtualBox's built-in DHCP server** on the host-only network (VirtualBox Manager → Network Manager), to avoid two servers on one network.
2. **Installed the role** on DC01:
   ```powershell
   Install-WindowsFeature DHCP -IncludeManagementTools
   ```
3. **Finished the post-install wizard** in Server Manager, which authorises the server in AD.
4. **Created an IPv4 scope** (`Lab host-only`) with the subnet, an address range, a lease time and these options:
   - **006**: DNS server `192.168.56.10`
   - **015**: domain name `lab.local`
5. **Switched the Win 11 host-only adapter** to automatic for both IP and DNS.

## The issue

Win 11 kept getting its lease from **`192.168.56.100`** (VirtualBox's DHCP server), not from DC01, and it had no DNS server.

## Troubleshooting

1. `ipconfig /all`: DHCP Server was `192.168.56.100`, and no DNS server was listed.
2. `ipconfig /release` then `/renew`: same lease from `.100` again, so it wasn't a stale lease.
3. `Get-DnsClientServerAddress -AddressFamily IPv4` returned `{}`.
4. `Get-DhcpServerv4Binding` on DC01 returned **nothing**: the DHCP service wasn't listening on any interface.
5. Powered off both VMs and closed VirtualBox. Task Manager showed no VirtualBox DHCP process.
6. Next morning, DC01 was listed as both DHCP and DNS server.

## Root cause

**Not confirmed.** The most likely explanation is two factors together:
- VirtualBox's DHCP kept answering despite showing as disabled.
- DC01's DHCP service wasn't bound to an interface (empty bindings), so it wasn't competing.

A full power-off probably reset both.

## What I'd check next time

```powershell
Get-Service DHCPServer
Restart-Service DHCPServer
Get-DhcpServerv4Binding
Get-DhcpServerv4Lease -ScopeId 192.168.56.0
```
- On the host: `VBoxManage list dhcpservers`
- Check the **DHCP Server** line in `ipconfig /all` to see who answered.

## Takeaways

- The **DHCP Server** line in `ipconfig /all` shows which server issued the lease.
- Empty DHCP bindings mean the service isn't listening, so restart it and recheck.
- Windows 11 has separate settings for IP and DNS assignment, and both need to be automatic.
