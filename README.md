# dots (Debian 13)

Setup z NixOS (`nix-dots`) przeniesiony na Debiana 13: **xmonad** (X11) z
**picomem** (animacje, cienie, zaokrąglone rogi, blur), **quickshell** (pasek
u góry + launcher), **fish**, **wezterm**, **neovim** (AstroNvim). Bez Nixa,
wallusta, tapet, dashboardu i file managera. Nic nie zależy od jednostek
systemd: sesja startuje z `startx`, a wszystko inne odpala
`xmonad/autostart`. Paleta kolorów (Rosé Pine) jest stała.

```
xmonad/xmonad.hs     -> ~/.config/xmonad   (WM, layouty, wszystkie skróty, stan dla paska)
xmonad/autostart     -> ~/.config/xmonad   (picom, quickshell, dunst, audio, Slack)
picom/picom.conf     -> ~/.config/picom    (animacje, cienie, rogi, blur)
dunst/               -> ~/.config/dunst    (powiadomienia + licznik Slacka)
lazygit/config.yml   -> ~/.config/lazygit  (bez niego `spacja gg` w nvimie od razu się zamyka)
tools/qs-tools/      indeks aplikacji launchera w Ruście (`cargo install`, krok 4)
quickshell/          -> ~/.config/quickshell (pasek + launcher)
bin/                 -> ~/.local/bin       (monitors, shot, screenrec, ocr-clip, touchpad-toggle, slack-autostart)
xinitrc              -> ~/.xinitrc         (kopiowany, tylko gdy go nie ma)
fish/      -> ~/.config/fish
wezterm/   -> ~/.config/wezterm
nvim/      -> ~/.config/nvim
wal/       -> ~/.cache/wal/colors-wal.vim   (paleta dla motywu nvim)
install.sh    linkuje powyższe, robi kopie zapasowe istniejących configów
```

Wszystko poniżej instaluje się z apt, z oficjalnych release'ów na GitHubie,
przez `cargo` / `go`, bez snapa i flatpaka. Komendy działają tak samo w fishu i
w bashu.

## 0. xmonad, picom, X11 i narzędzia do skrótów

```sh
sudo apt install xserver-xorg-core xserver-xorg-input-libinput xinit \
  x11-xserver-utils x11-xkb-utils x11-utils xinput dbus-bin \
  xmonad libghc-xmonad-contrib-dev picom hsetroot pavucontrol \
  i3lock xclip xdotool maim slop jq ffmpeg grabc \
  tesseract-ocr tesseract-ocr-pol brightnessctl \
  pipewire pipewire-pulse wireplumber pulseaudio-utils \
  papirus-icon-theme python3 dunst libnotify-bin \
  unicode-data fonts-noto-color-emoji playerctl flameshot lazygit btop
```

- `xmonad` + `libghc-xmonad-contrib-dev`: xmonad kompiluje `xmonad.hs`
  GHC-kiem (ciągnie go ta paczka). `install.sh` robi pierwszą kompilację,
  `super+alt+w` kompiluje i restartuje po zmianach (okna zostają).
- `picom` (12+, tyle ma Debian 13): animacje i przezroczystość. Bez niego
  wszystko działa, ale bez animacji, a odstępy między wyspami paska są czarne.
- `hsetroot`: kolor tła pulpitu (z `xsetroot` pod picomem tło jest czarne).
- `x11-utils` (`xprop`): pasek czyta przez niego stan xmonada.
- `unicode-data` + `fonts-noto-color-emoji`: emoji w launcherze (`super+.`).
- `flameshot`: screenshot z adnotacją (`super+ctrl+shift+s`); `super+shift+s` i `Print` robią zwykły.
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

## 3. WezTerm

Debian nie ma wezterma w repo. Oficjalne repo apt projektu:

```sh
curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg
sudo apt update && sudo apt install wezterm
```

Alternatywa: `.deb` dla Debiana 12 z
[releases](https://github.com/wezterm/wezterm/releases) albo
[wezterm.org/install/linux](https://wezterm.org/install/linux.html).

## 4. Rust i narzędzia z cargo

```sh
rustup default stable
rustup component add rust-analyzer clippy   # LSP dla Rusta w nvim, `clippy` (alias fisha)

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
xmonada (w `dbus-run-session`, gdy nie ma sesyjnego D-Bus, np. bez systemd).
Jeśli `~/.xinitrc` został z bspwm, zamień w nim `bspwm` na `xmonad`
(`install.sh` o tym przypomina). Wystarczy też samo `exec xmonad`: xmonad
sam dopisuje `~/.local/bin` do `PATH` i, gdy nie ma sesyjnego D-Bus,
uruchamia się ponownie w `dbus-run-session` (bez tego nie działały skróty
do zrzutów, nagrywania i flameshota).
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

Pełna lista: `super+s` otwiera okno ze wszystkimi skrótami pogrupowanymi
w sekcje, z wyszukiwarką (wpisz np. `zrzut`; Esc zamyka). Źródło:
`quickshell/Help.qml`, przy zmianie skrótów w `xmonad.hs` (`myKeys`)
popraw też tam.

| skrót | akcja |
| --- | --- |
| `super+Return` / `super+q` | wezterm / librewolf (albo firefox-esr) |
| `super+r` | launcher (aplikacje, otwarte okna, kalkulator `2*21`, emoji po `:`, pliki w `~`) |
| `super+n` | Slack: przełącz na niego albo uruchom |
| ``super+` `` / `super+b` | scratchpad: terminal / btop (wysuwa się nad wszystko, ten sam skrót chowa) |
| `super+h/l`, `super+←/→/↑/↓` | fokus okna w tym kierunku |
| `super+k/j`, `super+Tab` | poprzedni / następny / ostatni workspace |
| `super+1..9` / `super+shift+1..9` | workspace (ten sam numer drugi raz wraca) / przenieś okno |
| `super+shift+h/l/←/→/↑/↓` | zamień okno z sąsiadem |
| `super+shift+k/j` | przenieś okno na poprzedni / następny workspace |
| `super+shift+Return` | okno na miejsce mastera |
| `super+ctrl+…` / `super+shift+ctrl+…` | fokus monitora / okno na monitor |
| `super+scroll` / scroll na pasku | przełączanie workspace'ów |
| `super+u` | skocz do okna, które woła o uwagę |
| `super+shift+c` | zamknij okno |
| `super+t` / `super+f` | floating / fullscreen (chowa pasek) |
| `super+m` / `super+space` | następny layout: tall → wide → cols → full (nazwa wyskakuje na środku ekranu) |
| `super+shift+space` | layout z powrotem na tall |
| `super+g` | odstępy między oknami on/off |
| `super+[` `]` / `super+shift+[` `]` | szerokość mastera / wysokość okna w stosie |
| `super+=` / `super+-` | więcej / mniej okien w kolumnie mastera |
| `super+shift+s` / `Print` | screenshot obszaru (plik + schowek) |
| `super+ctrl+shift+s` | screenshot obszaru z adnotacją (flameshot) |
| `super+ctrl+s` | screenshot okna (plik + schowek) |
| `super+shift+r` / `super+ctrl+r` / `super+alt+r` | nagrywanie obszaru / monitora pod kursorem / obszaru z dźwiękiem; ten sam skrót drugi raz kończy (plik w `~/Videos/Recordings` + schowek). Na pasku czerwona kropka z czasem, klik kończy. Kodowanie na GPU AMD (VAAPI), bez niego x264. To samo z launchera: wpisz `nagr` / `rec` → Nagraj wycinek / cały ekran / wycinek z dźwiękiem / Zatrzymaj |
| `super+shift+t` | OCR obszaru do schowka |
| `super+p` | pipeta koloru (`grabc`) |
| `super+.` | emoji w launcherze (albo `:` i nazwa w launcherze) |
| `super+alt+t` | touchpad on/off |
| `super+alt+l` | blokada (`i3lock`) |
| `super+alt+w` | monitory, rekompilacja i restart xmonada, przeładowanie paska |
| `super+shift+e` | wyjście z xmonada |
| klawisze multimedialne | głośność, mikrofon, play/next/prev (`playerctl`), jasność |

Mysz: `super` + lewy przycisk przesuwa okno (robi je pływającym), `super` +
prawy zmienia rozmiar.

## Pasek

Na górze każdego ekranu, „wyspy” z zaokrąglonymi rogami:

- **lewo**: logo Debiana (klik: launcher), workspace'y z ikonami okien,
  które na nich są (aktywny na tym ekranie podświetlony i szerszy,
  widoczny na innym monitorze z obwódką, wołający o uwagę na czerwono;
  klik przełącza). Layoutu nie ma na stałe: po zmianie skrótem jego nazwa
  i ikona wyskakują na sekundę na środku ekranu.
- **środek**: aktywne okno, ikona + tytuł (na ekranie z fokusem).
- **prawo**: nagrywanie, Slack, głośność (scroll zmienia, klik wycisza,
  prawy klik: pavucontrol), bateria (tylko na laptopie), tray, zegar
  (klik: data).

Stan bierze z xmonada: `xmonad.hs` (`barLog`) zapisuje JSON we
właściwości `_XMONAD_LOG` okna root, `quickshell/Xmonad.qml` czyta ją przez
`xprop -spy`. Podgląd: `xprop -root _XMONAD_LOG`.

## Monitory

`bin/monitors` (odpalany z `xmonad/autostart` i przez `super+alt+w`)
ustawia zewnętrzne ekrany po lewej, panel laptopa (eDP) po prawej, każdy w
natywnej rozdzielczości z najwyższym odświeżaniem (eDP 2560x1600@240).

Workspace'y 1-9 są wspólne dla wszystkich monitorów (tak działa xmonad):
każdy monitor pokazuje jeden z nich, `super+N` wyciąga workspace N na
monitor z fokusem (jeśli był na drugim, monitory się nim zamieniają).

- Inna kolejność: zapisz nazwy od lewej do prawej w
  `~/.config/xmonad/monitor-order` (stary `~/.config/bspwm/monitor-order`
  też działa) i wciśnij `super+alt+w`:
  ```fish
  xrandr --query | grep ' connected'        # nazwy wyjść
  echo "eDP HDMI-A-0" > ~/.config/xmonad/monitor-order
  ```
  Sterownik amdgpu nazywa je `eDP`/`HDMI-A-0`, modesetting `eDP-1`/`HDMI-1`.
  Plik jest w `.gitignore`, bo zależy od komputera.
- Po podłączeniu monitora w trakcie sesji: `super+alt+w`. Okna zostają na
  swoich workspace'ach.
- Skalowanie: X11 nie ma skali per monitor jak Wayland. Dla jednej wspólnej
  skali dopisz `Xft.dpi: 120` (lub 144) do `~/.Xresources`.
- Laptop hybrydowy na sterowniku nvidia: jeśli `xrandr --query` nie widzi
  zewnętrznego ekranu (podpięty do NVIDII), skrypt sam próbuje
  `xrandr --setprovideroutputsource NVIDIA-G0 modesetting` (reverse PRIME).

## Slack, tray i powiadomienia

Slack ma na pasku **własny przycisk**, niezależny od traya: widać go zawsze,
gdy Slack jest zainstalowany (wyszarzony, gdy nie działa). Czerwony licznik
to liczba powiadomień ze Slacka od ostatniego przełączenia się na niego.
Klik albo `super+n` otwiera Slacka (uruchamia go, gdy nie działa) i zeruje
licznik. Licznik zeruje się też sam, gdy okno Slacka dostaje fokus.

- Licznik liczy `dunst`: reguła `[slack]` w `dunstrc` odpala
  `dunst/slack-count` przy każdym powiadomieniu Slacka. W Slacku muszą być
  włączone powiadomienia na pulpicie.
- Slack startuje sam z sesją, schowany do traya (`bin/slack-autostart`, z
  `xmonad/autostart`). Czeka, aż tray paska będzie gotowy, bo Slack
  (Electron) szuka traya tylko przy starcie. Wcześniej to był powód, dla
  którego ikona się nie pokazywała. Nie chcesz autostartu: usuń ostatnią
  linię z `xmonad/autostart`.
- Tray (StatusNotifierItem, ten sam protokół co w KDE) jest po prawej.
  Aplikacje, które mają tylko stary tray XEmbed, się tam nie pokażą.
- `super+alt+w` przeładowuje quickshell bez zabijania procesu, więc ikony w
  trayu zostają.
- Nowe wiadomości wyskakują jako powiadomienia `dunst` w prawym górnym rogu,
  pod paskiem. Test: `notify-send test "działa"`, licznika Slacka:
  `notify-send -a Slack Ktoś "cześć"`.

Kwadraciki zamiast ikon (np. baterii) znaczą brak czcionki Iosevka Nerd
Font (krok 2).

## Kolory

Paleta jest w dwóch miejscach, które trzeba trzymać zgodne:

- `wezterm/wezterm.lua`: `colors` (`background`, `foreground`, `cursor_*`, `ansi`, `brights`)
- `wal/colors-wal.vim`: te same wartości dla motywu nvim (neopywal)

Domyślnie jest Rosé Pine (paleta wallusta z setupu NixOS). Po zmianie `wal/colors-wal.vim` uruchom
ponownie `./install.sh`, bo kopiuje on paletę do `~/.cache/wal/`. Działający
nvim przeładuje motyw sam. WezTerm przeładowuje config sam po zapisie.

## Różnice względem `main` (NixOS)

- fish: bez aliasów Nixa, `grubup` to `update-grub`, nowy alias `up`
  (`apt update` + `full-upgrade`). Wszystkie aliasy do dodatkowych narzędzi
  są warunkowe.
- nvim: LSP i formattery instaluje Mason (na NixOS były z Nixa), parsery
  treesitter kompilują się lokalnie. Bez packa Nix. Formatuje tylko conform
  (wcześniej każdy zapis formatował dwa razy). Pluginy jak na NixOS: packi
  json/yaml/toml/markdown/fish, obsidian.nvim (sam znajduje vaulty
  Obsidiana), render-markdown, flash (`s`), yazi (`<Leader>-`), oil
  (`<Leader>O`), diffview, trouble (`<Leader>x`), todo-comments, grug-far.
- ghostty -> wezterm, stała paleta zamiast generowanej przez wallust.
- niri -> xmonad (X11) + picom: animacje otwierania/zamykania okien i
  zmiany workspace'ów (zoom), płynne przesuwanie okien przy zmianie
  layoutu, cienie, zaokrąglone rogi, blur pod przezroczystym weztermem.
  Ustawienia w `picom/picom.conf`; po zmianie `pkill picom; picom -b`.
- quickshell: pasek i launcher. Bez dashboardu (więc też
  bez kalendarza Google, kafelków i OSD), file managera, powiadomień i lock
  screena (blokuje `i3lock`). Bez „kofeiny”: na X11 nie ma tu demona
  usypiania, więc nie ma czego blokować.
- schowek: `xclip` zamiast `wl-clipboard` (fish `copy`/`paste`/`clipsave`
  wybierają narzędzie same, zależnie od sesji).

## Bez systemd

Nic tu nie jest jednostką systemd. Gdy init to systemd, pipewire startuje
przez socket activation jak zwykle. Na sysvinit/runit `xmonad/autostart` sam odpala
`pipewire`, `wireplumber` i `pipewire-pulse`, a `~/.xinitrc` tworzy sesyjny
D-Bus (`dbus-run-session`, potrzebny dla traya).
