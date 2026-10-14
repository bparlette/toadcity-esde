# Toad City Baltimore for ES-DE (EmulationStation Desktop Edition)

One-command installer to add **Toad City Baltimore** into your ES-DE game library on macOS.

## Quick Install

Open Terminal and run:

```bash
curl -fsSL https://raw.githubusercontent.com/bparlette/toadcity-esde/main/install_mac.sh | bash
```

### What this does automatically:
1. Downloads the latest universal macOS release of **Toad City Baltimore**.
2. Installs the app into `~/Applications` (and links `/Applications` for ES-DE access).
3. Adds the `toadcity` system into your ES-DE configuration (`custom_systems/es_systems.xml` & `custom_systems/es_find_rules.xml`), preserving all your other systems and settings.
4. Installs the ROM stub into your ES-DE ROMs directory (`toadcity/Toad City Baltimore.toadcity`).
5. Installs complete high-res media: screenshots, box covers, marquees, mix images, and video preview.

---

## Requirements
- macOS 12+ (Apple Silicon or Intel)
- [ES-DE](https://es-de.org) (EmulationStation Desktop Edition) installed

---

## Controls
- **Xbox / PlayStation Controller**:
  - `A` / `Cross`: Jump
  - `X` / `Square` or `B` / `Circle`: Attack / Swing
  - `Y` / `Triangle`: Action / Interact
  - `LB` / `RB`: Rotate Camera
  - `View` / `Select`: Map
  - `Menu` / `Start`: Pause
  - Hold `View + Menu` (or `Select + Start`) for 1 second to exit back to ES-DE.
- **Keyboard**:
  - `WASD` or Arrow keys: Move
  - `Space`: Jump
  - `J` / `K`: Attack
  - `E`: Action
  - `Esc`: Pause / Quit

---

## Uninstall

If you ever wish to remove Toad City Baltimore from ES-DE:

```bash
curl -fsSL https://raw.githubusercontent.com/bparlette/toadcity-esde/main/uninstall_mac.sh | bash
```
