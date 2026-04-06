# Badger Overlay

Gentoo overlay with ebuilds for proprietary Russian and remote-desktop software.

## Packages

| Package | Description |
|---|---|
| `net-im/max` | [MAX](https://max.ru/) — desktop client for communication and collaboration |
| `app-office/r7-office` | [R7-Office](https://r7-office.ru/) — office suite compatible with Microsoft Office formats |

## Installation

### Using eselect-repository (recommended)

```bash
eselect repository add badger git https://github.com/deepbadger/badger-overlay.git
emerge --sync badger
```

### Manually

Create `/etc/portage/repos.conf/badger.conf`:

```ini
[badger]
location = /var/db/repos/badger
sync-type = git
sync-uri = https://github.com/deepbadger/badger-overlay.git
masters = gentoo
auto-sync = yes
```

Then sync:

```bash
emerge --sync badger
```

### Removal

```bash
eselect repository remove -f badger
```

Or if added manually — remove `/etc/portage/repos.conf/badger.conf` and delete the repository directory:

```bash
rm -rf /var/db/repos/badger
```

## Usage

```bash
# MAX messenger
emerge net-im/max

# R7-Office
emerge app-office/r7-office

## License

Ebuilds are distributed under the [GNU General Public License v2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html).
The packaged software is subject to its own respective licenses.
