# Troubleshooting

Common issues and solutions when deploying the arr-stack.

## Deployment Issues

### Network Creation Fails

**Symptom:** `docker network create` fails with "network already exists" error.

**Cause:** Orphaned network from a previous failed deployment.

**Fix:**
```bash
# Check for orphaned networks
./scripts/check-network.sh

# Or clean all unused networks
docker network prune

# Or remove specific network
docker network rm traefik-proxy
```

### VPN Connection Fails with DNS Timeout

**Symptom:** Gluetun logs show `lookup github.com: i/o timeout` or similar DNS errors.

**Possible causes:**

1. **Orphaned network** - Gluetun can't reach Pi-hole. Run `./scripts/check-network.sh` and redeploy.

2. **Wrong subnet in firewall rules** - If your LAN is `192.168.1.x` (not `192.168.0.x`), set `LAN_SUBNET=192.168.1.0/24` in your `.env`.

3. **Pi-hole not ready** - Should resolve automatically (gluetun waits for Pi-hole), but if it persists, check Pi-hole logs: `docker logs pihole`.

**Quick workaround:** Use public DNS instead of Pi-hole:
```bash
# In docker-compose.arr-stack.yml, change:
- DNS_ADDRESS=192.168.100.5
# To:
- DNS_ADDRESS=1.1.1.1
```
Trade-off: VPN traffic won't get Pi-hole ad-blocking.

### Services Can't Connect to Each Other

**Symptom:** Sonarr shows "Unable to connect to qBittorrent" or similar.

**Cause:** VPN-protected services share Gluetun's network. If gluetun was recreated but other services weren't, they point to a stale network namespace.

**Fix:**
```bash
# Recreate all services (not just restart)
docker compose -f docker-compose.arr-stack.yml up -d --force-recreate
```

See [REFERENCE.md](REFERENCE.md#service-connection-guide) for which services use localhost vs gluetun hostname.

## Network Issues

### `.lan` Domains Not Resolving

**Symptom:** `http://sonarr.lan` doesn't work but `http://NAS_IP:8989` does.

**Possible causes:**

1. **Router not using Pi-hole for DNS** - Set your router's DHCP to use Pi-hole IP as primary DNS.

2. **Pi-hole DNS entries missing** - Check `pihole/02-local-dns.conf` exists with correct entries.

3. **Browser DNS cache** - Try incognito mode or clear DNS cache.

### Home Assistant Can't Reach Arr Services

**Symptom:** Home Assistant can't connect to Sonarr/Radarr via IP.

**Cause:** Gluetun firewall blocks incoming connections by default.

**Fix:** Ensure `LAN_SUBNET` in `.env` matches your actual LAN. Gluetun's `FIREWALL_OUTBOUND_SUBNETS` uses this to allow local network access.

## Pi-hole Issues

### Network Goes Down When Pi-hole Stops

**Symptom:** All devices lose internet when Pi-hole container stops.

**Cause:** Your router uses Pi-hole as DNS. When Pi-hole stops, DNS resolution fails network-wide.

**Prevention:**
- Never use `docker compose down` on the arr-stack
- Use `docker compose up -d --force-recreate` to restart

**Recovery:**
1. Connect to mobile hotspot (different network)
2. SSH to NAS using IP address (not hostname): `ssh user@192.168.x.x`
3. Start the stack: `docker compose -f docker-compose.arr-stack.yml up -d`
4. Wait 30 seconds, reconnect to home WiFi

### Pi-hole Web UI Shows Wrong Password

**Symptom:** Can't log in to Pi-hole admin despite correct password.

**Fix:** Password may not have been set on first run. Reset it:
```bash
docker exec pihole pihole setpassword
```

## VPN Issues

### VPN Shows Wrong Country/IP

**Symptom:** `docker exec gluetun wget -qO- ifconfig.me` shows wrong country.

**Cause:** VPN connected to different server than expected.

**Fix:** Set specific country in `.env`:
```bash
VPN_COUNTRIES=United Kingdom
```

### Downloads Are Slow

**Possible causes:**

1. **VPN server congestion** - Try a different country/server.

2. **qBittorrent throttled** - Check Tools → Options → Speed for limits.

3. **ISP throttling** - Some ISPs throttle VPN traffic. Try different VPN protocol (OpenVPN vs WireGuard).

## Container Issues

### Container Keeps Restarting

**Symptom:** Container shows "Restarting" in `docker ps`.

**Check logs:**
```bash
docker logs <container_name> --tail 50
```

Common causes:
- Missing environment variables
- Permission issues on volumes
- Port already in use

### Container Shows "Unhealthy"

**Symptom:** `docker ps` shows `(unhealthy)` status.

**Fix:** Check container logs for the health check failure reason:
```bash
docker inspect <container_name> --format '{{json .State.Health}}'
```
