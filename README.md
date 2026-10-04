# dots (Debian 13)

Tylko terminal z setupu NixOS (`main`): **fish**, **ghostty**, **neovim**
(AstroNvim). Bez Nixa, quickshella, niri i wallusta. Paleta kolorów jest
stała zamiast generowanej z tapety.

```
fish/      -> ~/.config/fish
ghostty/   -> ~/.config/ghostty
nvim/      -> ~/.config/nvim
wal/       -> ~/.cache/wal/colors-wal.vim   (paleta dla motywu nvim)
install.sh    linkuje powyższe, robi kopie zapasowe istniejących configów
```

Wszystko poniżej instaluje się z apt, z oficjalnych release'ów na GitHubie,
przez `cargo` / `go`, bez snapa i flatpaka.

## 1. Pakiety z apt

```sh
sudo apt update
sudo apt install fish git curl wget unzip build-essential pkg-config \
  ripgrep fd-find fzf bat eza zoxide fastfetch wl-clipboard direnv \
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
git clone -b debian https://github.com/dhmztr/nix-dots ~/dots
~/dots/install.sh
chsh -s "$(command -v fish)"     # fish jako domyślna powłoka (po relogowaniu)
```

`install.sh` tworzy symlinki, więc `git pull` w `~/dots` od razu aktualizuje
configi. Istniejące katalogi przenosi do `*.bak-<data>`.

Pierwsze uruchomienie `nvim` pobiera pluginy (lazy.nvim), a Mason doinstalowuje
serwery LSP i formattery. Postęp widać w `:Lazy` i `:Mason`. Może to potrwać
kilka minut.

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
  treesitter kompilują się lokalnie. Usunięte pakiety Nix i Haskell.
- ghostty: stała paleta zamiast generowanej przez wallust.
