# ⛏️ Verus Miner

<div align="center">

### Lightweight VRSC CPU Mining Launcher

**Linux • ARM64 • x86_64 • systemd • Auto-restart**

![Verus](https://img.shields.io/badge/Verus-VRSC-7c3aed?style=for-the-badge)
![Linux](https://img.shields.io/badge/Linux-supported-111827?style=for-the-badge&logo=linux)
![ARM64](https://img.shields.io/badge/ARM64-supported-111827?style=for-the-badge)

</div>

---

## Features

- CPU mining with VerusHash
- ARM64 and x86_64 support
- Interactive configuration
- systemd service
- Automatic restart after miner failure
- CPU thread control
- Clean terminal status
- Journal/log support
- No wallet secrets or credentials are committed to Git

## Quick start

```bash
git clone https://github.com/KancellKe2/verus-miner.git
cd verus-miner
chmod +x *.sh
sudo ./install.sh
```

The installer asks for:

- VRSC wallet address
- pool URL
- worker name
- CPU thread count

Then start:

```bash
sudo systemctl start verus-miner
```

Check:

```bash
sudo ./status.sh
```

Follow logs:

```bash
sudo journalctl -u verus-miner -f
```

## Configuration

The installed configuration is:

```text
/etc/verus-miner/config.env
```

Example:

```ini
WALLET=YOUR_VRSC_ADDRESS
POOL=stratum+tcp://pool.verus.io:9999
WORKER=stb-01
THREADS=4
PASSWORD=x
```

The Verus documentation currently lists CCminer v3.8.3a for Linux and ARM mining. This project downloads the published CPU binary rather than committing a miner binary into this repository.

Official mining documentation:

https://docs.verus.io/economy/start-mining.html

CCminer CPU release used by the installer:

https://github.com/Oink70/ccminer-verus/releases/tag/v3.8.3a-CPU

## Commands

```bash
sudo ./start.sh
sudo ./stop.sh
sudo ./restart.sh
sudo ./status.sh
sudo ./uninstall.sh
```

Or directly:

```bash
sudo systemctl start verus-miner
sudo systemctl stop verus-miner
sudo systemctl restart verus-miner
sudo systemctl status verus-miner
```

## CPU usage

Mining can use substantial CPU resources. Set `THREADS` conservatively on small SBC/STB systems that also run DNS, proxy, storage, or other services.

## Security

Only run this miner on systems you own or are authorized to use. The installer is intentionally explicit: it does not hide the process, modify SSH access, or silently start mining.

Review scripts before running them on production systems.

## License

GPL-3.0-or-later.
