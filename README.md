# dots (Debian 13)

Setup z NixOS (`nix-dots`) przeniesiony na Debiana 13: **bspwm + sxhkd**
(X11) z tymi samymi skrótami co niri, **quickshell** (pasek + launcher),
**fish**, **ghostty**, **neovim** (AstroNvim). Bez Nixa, wallusta, tapet,
dashboardu i file managera. Nic nie zależy od jednostek systemd: sesja
startuje z `startx`, a wszystko inne odpala `bspwmrc`. Paleta kolorów
(Rosé Pine) jest stała.

```
bspwm/bspwmrc        -> ~/.config/bspwm    (WM, autostart: sxhkd, quickshell, audio)
sxhkd/sxhkdrc        -> ~/.config/sxhkd    (wszystkie skróty)
dunst/dunstrc        -> ~/.config/dunst    (powiadomienia)
lazygit/config.yml   -> ~/.config/lazygit  (bez niego `spacja gg` w nvimie od razu się zamyka)
tools/qs-tools/      indeks aplikacji launchera w Ruście (`cargo install`, krok 4)
quickshell/          -> ~/.config/quickshell (pasek + launcher)
bin/                 -> ~/.local/bin       (monitors, shot, screenrec, ocr-clip, touchpad-toggle)
xinitrc              -> ~/.xinitrc         (kopiowany, tylko gdy go nie ma)
fish/      -> ~/.config/fish
ghostty/   -> ~/.config/ghostty
nvim/      -> ~/.config/nvim
wal/       -> ~/.cache/wal/colors-wal.vim   (paleta dla motywu nvim)
install.sh    linkuje powyższe, robi kopie zapasowe istniejących configów
```

Wszystko poniżej instaluje się z apt, z oficjalnych release'ów na GitHubie,
przez `cargo` / `go`, bez snapa i flatpaka. Komendy działają tak samo w fishu i
w bashu.

## 0. bspwm, X11 i narzędzia do skrótów

```sh
sudo apt install xserver-xorg-core xserver-xorg-input-libinput xinit \
  x11-xserver-utils x11-xkb-utils xinput dbus-bin \
  bspwm sxhkd i3lock xclip xdotool maim slop jq ffmpeg grabc \
  tesseract-ocr tesseract-ocr-pol brightnessctl \
  pipewire pipewire-pulse wireplumber pulseaudio-utils \
  papirus-icon-theme python3 dunst libnotify-bin \
  unicode-data fonts-noto-color-emoji playerctl flameshot lazygit btop
```

- `unicode-data` + `fonts-noto-color-emoji`: emoji w launcherze (`super+.`).
- `flameshot`: screenshot z adnotacją (`super+shift+s`), `Print` robi zwykły.
- `lazygit`: `spacja gg` w nvimie (config w `lazygit/`).

## 0.1 quickshell (budowanie ze źródeł)

Debian nie ma quickshella w repo. Budowa tylko z X11 (bez Wayland/Hyprland,
PAM, polkit, greetd), więc zależności są małe:

```sh
sudo apt install git cmake ninja-build pkg-config g++ \
  qt6-base-dev qt6-base-private-dev qt6-declarative-dev \
  qt6-declarative-private-dev qt6-shadertools-dev spirv-tools \
  libcli11-dev libdrm-dev libxcb1-dev \
  qml6-module-qtquick qml6-module-qtqml-workerscript qml6-module-qtcore \
  qml6-module-qtquick-window qt6-svg-plugins

git clone https://github.com/quickshell-mirror/quickshell ~/src/quickshell
cd ~/src/quickshell
git checkout v0.3.0      # przetestowana wersja (ta sama co w nixpkgs)
cmake -GNinja -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DUSE_JEMALLOC=OFF -DCRASH_HANDLER=OFF -DWAYLAND=OFF -DHYPRLAND=OFF \
  -DSCREENCOPY=OFF -DI3=OFF -DSERVICE_PIPEWIRE=OFF -DSERVICE_PAM=OFF \
  -DSERVICE_POLKIT=OFF -DSERVICE_GREETD=OFF -DSERVICE_NOTIFICATIONS=OFF \
  -DBLUETOOTH=OFF -DNETWORK=OFF
cmake --build build
sudo cmake --install build
quickshell --version
```

Nowsza wersja: `git fetch --tags; git checkout <tag>` i znowu `cmake --build build`
oraz `sudo cmake --install build`.

`qt6-svg-plugins` jest potrzebny do ikon SVG w launcherze, bez niego ikony
są puste.

## 1. Pakiety z apt

```sh
sudo apt update
sudo apt install fish git curl wget unzip build-essential pkg-config \
  ripgrep fd-find fzf bat eza zoxide fastfetch xclip direnv \
  duf just tealdeer gping tokei rustup golang-go nodejs npm \
  python3-venv clangd fontconfig
```

- Debian nazywa część programów inaczej: `bat` to `batcat`, `fd` to `fdfind`.
  Config fisha sam to obsługuje (`bat`, `cat` i `fd` działają normalnie).
- Jeśli apt nie znajdzie któregoś pakietu, pomiń go i doinstaluj przez
  `cargo` (krok 4). Fish ustawia alias tylko wtedy, gdy program istnieje,
  więc brakujące narzędzie nie powoduje błędów.

## 2. Czcionka: Iosevka Nerd Font

```sh
mkdir -p ~/.local/share/fonts/iosevka
cd /tmp
curl -LO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Iosevka.zip
unzip -o Iosevka.zip -d ~/.local/share/fonts/iosevka
fc-cache -f
```

## 3. Ghostty

Debian nie ma ghostty w repo, a projekt nie wydaje oficjalnych paczek `.deb`.
Najprościej przez nieoficjalne paczki
[mkasberg/ghostty-ubuntu](https://github.com/mkasberg/ghostty-ubuntu)
(wspiera Debian Trixie):

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)"
```

Alternatywa: budowanie ze źródeł wg
[ghostty.org/docs/install/build](https://ghostty.org/docs/install/build)
(wymaga Ziga w wersji podanej w dokumentacji).

## 4. Rust i narzędzia z cargo

```sh
rustup default stable
rustup component add rust-analyzer      # LSP dla Rusta w nvim

# cargo-binstall pobiera gotowe binarki zamiast kompilować (dużo szybciej)
cargo install cargo-binstall
cargo binstall -y atuin du-dust procs ouch zellij broot xh tree-sitter-cli yazi-fm yazi-cli
# dev: ciągły cargo check, szybsze testy, czyszczenie target/, benchmarki,
# fuzzy finder z podglądem, ruch sieciowy per proces
cargo binstall -y bacon cargo-nextest kondo hyperfine television bandwhich
sudo setcap cap_sys_ptrace,cap_dac_read_search,cap_net_raw,cap_net_admin+ep "$(command -v bandwhich)"

# indeks aplikacji dla launchera w Ruście (z tego repo; bez niego launcher
# używa wersji w Pythonie)
cargo install --path ~/dots/tools/qs-tools --bin qs-apps
```

`tree-sitter-cli` jest potrzebny nvimowi do kompilowania parserów składni.

## 4.1 Haskell (ghcup)

Oficjalny instalator, bez snapa. Daje GHC, cabal i haskell-language-server w
pasujących wersjach (nvim: pack haskell, formatowanie fourmolu przez Mason):

```sh
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
ghcup install hls --set
cabal install hlint ghcid hoogle
hoogle generate          # baza do wyszukiwania po typach (telescope_hoogle)
```

## 5. Narzędzia z Go

```sh
go install github.com/charmbracelet/glow/v2@latest       # podgląd markdown (cat plik.md)
go install github.com/mr-karan/doggo/cmd/doggo@latest    # dig
```

## 6. Neovim (nowszy niż w Debianie)

AstroNvim v6 potrzebuje Neovima 0.11+, a Debian 13 ma 0.10. Oficjalny
release do `/opt/nvim` (fish ma `/opt/nvim/bin` w PATH):

```sh
cd /tmp
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim && sudo mkdir -p /opt/nvim
sudo tar -C /opt/nvim --strip-components=1 -xzf nvim-linux-x86_64.tar.gz
```

Aktualizacja: te same komendy jeszcze raz.

## 7. Configi

```sh
git clone https://github.com/dhmztr/dots-debian ~/dots
~/dots/install.sh
chsh -s "$(command -v fish)"     # fish jako domyślna powłoka (po relogowaniu)
```

Start sesji: zaloguj się na tty i wpisz `startx`. `~/.xinitrc` uruchamia
bspwm (w `dbus-run-session`, gdy nie ma sesyjnego D-Bus, np. bez systemd).
Autostart bez display managera, na końcu `~/.config/fish/config.fish`:

```fish
if status is-login; and test -z "$DISPLAY"; and test (tty) = /dev/tty1
    exec startx
end
```

`install.sh` tworzy symlinki, więc `git pull` w `~/dots` od razu aktualizuje
configi. Istniejące katalogi przenosi do `*.bak-<data>`.

Pierwsze uruchomienie `nvim` pobiera pluginy (lazy.nvim), a Mason doinstalowuje
serwery LSP i formattery. Postęp widać w `:Lazy` i `:Mason`. Może to potrwać
kilka minut.

## Skróty (super = klawisz Windows)

Te same co w niri. Pełna lista: `super+s` albo `sxhkd/sxhkdrc`.

| skrót | akcja |
| --- | --- |
| `super+Return` / `super+q` | ghostty / librewolf (albo firefox-esr) |
| `super+r` | launcher (aplikacje, otwarte okna, kalkulator `2*21`, emoji po `:`, pliki w `~`) |
| `super+h/l`, `super+←/→/↑/↓` | fokus okna |
| `super+k/j`, `super+Tab` | poprzedni / następny / ostatni pulpit |
| `super+1..9` / `super+shift+1..9` | pulpit / przenieś okno, na aktywnym monitorze (ten sam numer drugi raz wraca) |
| `super+shift+h/l/←/→/↑/↓` | zamień okno z sąsiadem |
| `super+shift+k/j` | przenieś okno na poprzedni / następny pulpit |
| `super+ctrl+…` / `super+shift+ctrl+…` | fokus monitora / okno na monitor |
| `super+scroll` | przełączanie pulpitów |
| `super+shift+c` | zamknij okno |
| `super+t` / `super+f` / `super+m` | floating / fullscreen / monocle |
| `super+[` `]`, `super+shift+[` `]` | szerokość / wysokość okna |
| `super+shift+s` | screenshot obszaru z adnotacją (flameshot) |
| `Print` / `super+ctrl+s` | screenshot obszaru / okna (plik + schowek) |
| `super+shift+r` / `super+ctrl+r` / `super+alt+r` | nagrywanie obszaru / monitora / obszaru z dźwiękiem; ten sam skrót drugi raz kończy (plik w `~/Videos/Recordings` + schowek). Na pasku czerwona kropka z czasem, klik kończy. Kodowanie na GPU AMD (VAAPI), bez niego x264 |
| `super+shift+t` | OCR obszaru do schowka |
| `super+p` | pipeta koloru (`grabc`) |
| `super+.` | emoji w launcherze (albo `:` i nazwa w launcherze) |
| `super+alt+t` | touchpad on/off |
| `super+alt+l` | blokada (`i3lock`) |
| `super+alt+w` | przeładuj sxhkd i quickshell |
| `super+shift+e` | wyjście z bspwm |
| klawisze multimedialne | głośność, mikrofon, play/next/prev (`playerctl`), jasność |

Bez odpowiedników z niri: overview (`super+Esc`), centrowanie kolumny,
pierwsza/ostatnia kolumna (`super+Home/End`).

Mysz: `super` + lewy przycisk przesuwa okno, `super` + prawy zmienia rozmiar.
Pasek: kropki to pulpity (klik przełącza, scroll po pasku też), zegar
(klik: data), tray, bateria (tylko na laptopie).

## Monitory

Jak w niri na NixOS: `bin/monitors` (odpalany z `bspwmrc` i przez
`super+alt+w`) ustawia zewnętrzne ekrany po lewej, panel laptopa (eDP) po
prawej, każdy w natywnej rozdzielczości z najwyższym odświeżaniem (eDP
2560x1600@240). Każdy monitor ma własne pulpity 1-9, `super+1..9` i
`super+shift+1..9` działają na monitorze z fokusem, pasek na każdym ekranie
pokazuje jego pulpity.

- Inna kolejność: zapisz nazwy od lewej do prawej w
  `~/.config/bspwm/monitor-order` i wciśnij `super+alt+w`:
  ```fish
  xrandr --query | grep ' connected'        # nazwy wyjść
  echo "eDP HDMI-A-0" > ~/.config/bspwm/monitor-order
  ```
  Sterownik amdgpu nazywa je `eDP`/`HDMI-A-0`, modesetting `eDP-1`/`HDMI-1`.
  Plik jest w `.gitignore`, bo zależy od komputera.
- Po podłączeniu monitora w trakcie sesji: `super+alt+w`. Okna na
  istniejących pulpitach zostają.
- Skalowanie: X11 nie ma skali per monitor jak niri. Dla jednej wspólnej
  skali dopisz `Xft.dpi: 120` (lub 144) do `~/.Xresources`.
- Laptop hybrydowy na sterowniku nvidia: jeśli `xrandr --query` nie widzi
  zewnętrznego ekranu (podpięty do NVIDII), skrypt sam próbuje
  `xrandr --setprovideroutputsource NVIDIA-G0 modesetting` (reverse PRIME).

## Tray i powiadomienia (Slack)

Tray jest na dole paska (protokół StatusNotifierItem, ten sam co w KDE i na
NixOS). Nieprzeczytane w Slacku widać po kropce na jego ikonie, a nowe
wiadomości wyskakują jako powiadomienia `dunst` w prawym górnym rogu.

- Slack (i inne aplikacje Electron) rejestruje ikonę tylko przy starcie,
  więc musi wystartować, gdy pasek już działa. Jeśli ikony nie ma, zamknij
  Slacka całkiem (`pkill -x slack`) i uruchom ponownie.
- `super+alt+w` przeładowuje quickshell bez zabijania procesu, więc ikony w
  trayu zostają.
- W ustawieniach Slacka musi być włączona ikona w trayu / obszarze
  powiadomień.
- Aplikacje, które mają tylko stary tray XEmbed, się tu nie pokażą.
- Test powiadomień: `notify-send test "działa"`.

Kwadraciki zamiast ikon (np. baterii) znaczą brak czcionki Iosevka Nerd
Font (krok 2).

## Kolory

Paleta jest w dwóch miejscach, które trzeba trzymać zgodne:

- `ghostty/config`: `background`, `foreground`, `cursor-color`, `palette = 0..15`
- `wal/colors-wal.vim`: te same wartości dla motywu nvim (neopywal)

Domyślnie jest Rosé Pine (paleta wallusta z setupu NixOS). Po zmianie `wal/colors-wal.vim` uruchom
ponownie `./install.sh`, bo kopiuje on paletę do `~/.cache/wal/`. Działający
nvim przeładuje motyw sam. Ghostty przeładuje config po `ctrl+shift+,`.

## Różnice względem `main` (NixOS)

- fish: bez aliasów Nixa, `grubup` to `update-grub`, nowy alias `up`
  (`apt update` + `full-upgrade`). Wszystkie aliasy do dodatkowych narzędzi
  są warunkowe.
- nvim: LSP i formattery instaluje Mason (na NixOS były z Nixa), parsery
  treesitter kompilują się lokalnie. Bez packa Nix. Formatuje tylko conform
  (wcześniej każdy zapis formatował dwa razy). Pluginy jak na NixOS: packi
  json/yaml/toml/markdown/fish/haskell, obsidian.nvim (sam znajduje vaulty
  Obsidiana), render-markdown, flash (`s`), yazi (`<Leader>-`), oil
  (`<Leader>O`), diffview, trouble (`<Leader>x`), todo-comments, grug-far.
- ghostty: stała paleta zamiast generowanej przez wallust.
- niri -> bspwm (X11). Brak kompozytora, więc nie ma przezroczystości ani
  cieni; pasek i launcher są nieprzezroczyste. Jeśli chcesz, doinstaluj
  `picom` i dopisz `picom -b` w `bspwmrc`.
- quickshell: pasek i launcher. Bez dashboardu (więc też
  bez kalendarza Google, kafelków i OSD), file managera, powiadomień i lock
  screena (blokuje `i3lock`). Bez „kofeiny”: na X11 nie ma tu demona
  usypiania, więc nie ma czego blokować.
- schowek: `xclip` zamiast `wl-clipboard` (fish `copy`/`paste`/`clipsave`
  wybierają narzędzie same, zależnie od sesji).

## Bez systemd

Nic tu nie jest jednostką systemd. Gdy init to systemd, pipewire startuje
przez socket activation jak zwykle. Na sysvinit/runit `bspwmrc` sam odpala
`pipewire`, `wireplumber` i `pipewire-pulse`, a `~/.xinitrc` tworzy sesyjny
D-Bus (`dbus-run-session`, potrzebny dla traya).
