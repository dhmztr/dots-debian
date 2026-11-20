-- xmonad (X11). Recompiled by `xmonad --recompile`; super+alt+w recompiles,
-- restarts xmonad in place (windows stay) and reloads the bar.
--
-- Pieces around it:
--   ~/.config/xmonad/autostart   session programs (picom, quickshell, dunst, ...)
--   ~/.config/picom/picom.conf   animations, shadows, rounded corners, blur
--   ~/.config/quickshell/        top bar + launcher; reads the state that
--                                barLog (bottom of this file) publishes
--
-- super+s opens the key overview (quickshell/Help.qml). Keys are in `myKeys`.

import XMonad
import qualified XMonad.StackSet as W

import XMonad.Actions.CycleWS (nextWS, prevWS, shiftToNext, shiftToPrev, toggleOrView, toggleWS)
import XMonad.Actions.Navigation2D
import XMonad.Actions.WindowGo (raiseMaybe)
import XMonad.Hooks.EwmhDesktops (ewmh, ewmhFullscreen)
import XMonad.Hooks.InsertPosition (Focus (Newer), Position (End), insertPosition)
import XMonad.Hooks.ManageDocks (ToggleStruts (..), avoidStruts, docks)
import XMonad.Hooks.ManageHelpers (doCenterFloat, doFullFloat, isDialog)
import XMonad.Hooks.SetWMName (setWMName)
import XMonad.Hooks.StatusBar (xmonadPropLog')
import XMonad.Hooks.UrgencyHook (NoUrgencyHook (..), focusUrgent, readUrgents, withUrgencyHook)
import XMonad.Layout.MultiToggle (Toggle (..), mkToggle, single)
import XMonad.Layout.MultiToggle.Instances (StdTransformers (NBFULL))
import XMonad.Layout.NoBorders (smartBorders)
import XMonad.Layout.Renamed (Rename (Replace), renamed)
import XMonad.Layout.ResizableTile (MirrorResize (..), ResizableTall (..))
import XMonad.Layout.Spacing (Border (..), spacingRaw, toggleScreenSpacingEnabled, toggleWindowSpacingEnabled)
import XMonad.Layout.ThreeColumns (ThreeCol (..))
import XMonad.Util.EZConfig (checkKeymap, mkKeymap)
import XMonad.Util.NamedScratchpad

import Control.Exception (SomeException, try)
import Control.Monad (forM, unless, when)
import Data.Char (ord, toLower)
import Data.List (elemIndex, intercalate, sortOn)
import Data.Monoid (All (..))
import qualified Data.Map as M
import Data.Maybe (fromMaybe, listToMaybe)
import System.Directory (doesPathExist)
import System.Environment (lookupEnv, setEnv)
import System.Exit (exitSuccess)
import System.Posix.Process (executeFile)
import Text.Printf (printf)

-- ---- look --------------------------------------------------------------------
-- Rosé Pine, same palette as wezterm / quickshell / dunst

colBorder, colFocused :: String
colBorder  = "#26233a"
colFocused = "#c4a7e7"

myWorkspaces :: [WorkspaceId]
myWorkspaces = map show [1 .. 9 :: Int]

-- ---- layouts -----------------------------------------------------------------
-- tall: master left, stack right | wide: master on top | cols: master in the
-- middle | full: one window at a time. super+m / super+space cycles them; the
-- new layout's name pops up in the middle of the screen (layoutOsd).

myLayout =
  avoidStruts . mkToggle (single NBFULL) . smartBorders . gaps $
    renamed [Replace "tall"] tall
      ||| renamed [Replace "wide"] (Mirror tall)
      ||| renamed [Replace "cols"] (ThreeColMid 1 (3 / 100) (1 / 2))
      ||| renamed [Replace "full"] Full
  where
    tall = ResizableTall 1 (3 / 100) (1 / 2) []
    -- 12px between windows and around the screen edge, like the bspwm setup
    gaps = spacingRaw False (Border 6 6 6 6) True (Border 6 6 6 6) True

-- ---- scratchpads -------------------------------------------------------------
-- Floating windows that drop down over everything and hide again with the
-- same key: a terminal (super+` or super+') and btop (super+b).
-- --always-new-process: a wezterm started while another one runs would
-- otherwise open its window in the running process, without the --class,
-- and xmonad would never recognise it as the scratchpad.

scratchpads :: [NamedScratchpad]
scratchpads =
  [ NS "term" "wezterm start --always-new-process --class scratch-term" (isClass "scratch-term") (centered 0.6 0.55)
  , NS "btop" "wezterm start --always-new-process --class scratch-btop -- btop" (isClass "scratch-btop") (centered 0.7 0.7)
  ]
  where
    isClass c = className =? c <||> appName =? c
    centered w h = customFloating $ W.RationalRect ((1 - w) / 2) ((1 - h) / 2) w h

-- ---- window rules ------------------------------------------------------------

myManageHook :: ManageHook
myManageHook =
  composeAll
    [ title =? "qs-launcher" --> doFullFloat -- quickshell launcher overlay
    , title =? "qs-help" --> doFullFloat -- quickshell key overview (super+s)
    , className =? "Pavucontrol" --> doCenterFloat
    , className =? "pavucontrol" --> doCenterFloat
    , className =? "Blueman-manager" --> doCenterFloat
    , className =? "flameshot" --> doFullFloat
    , isDialog --> doCenterFloat
    ]
    <> namedScratchpadManageHook scratchpads
    -- new windows go to the end of the stack instead of replacing the master
    <> insertPosition End Newer

-- ---- keys --------------------------------------------------------------------
-- super = M, alt = M1. Commands run under /bin/sh. Punctuation keys are
-- written as the character ("M-[", "M-`"); EZConfig silently drops names it
-- does not know (<grave>, <bracketleft>, ...), so the startup hook runs
-- checkKeymap, which pops up a message about any such binding.

myKeys :: [(String, X ())]
myKeys =
  -- apps
  [ ("M-<Return>", spawn "wezterm")
  , ("M-q", spawn "librewolf || firefox-esr")
  , ("M-r", spawn "quickshell ipc call launcher toggle")
  , ("M-s", spawn "quickshell ipc call help toggle")
  , ("M-n", raiseMaybe (spawn "slack") (className =? "Slack")) -- Slack: focus or start
  , ("M-`", namedScratchpadAction scratchpads "term")
  , ("M-'", namedScratchpadAction scratchpads "term")
  , ("M-b", namedScratchpadAction scratchpads "btop")
  , -- session
    ("M-S-e", io exitSuccess)
  , ("M-M1-w", spawn reload)
  , ("M-M1-l", spawn "i3lock -n -c 191724")
  , ("M-M1-t", spawn "touchpad-toggle")
  , ("<XF86TouchpadToggle>", spawn "touchpad-toggle")
  , -- focus
    ("M-h", windowGo L False)
  , ("M-l", windowGo R False)
  , ("M-<Left>", windowGo L False)
  , ("M-<Right>", windowGo R False)
  , ("M-<Up>", windowGo U False)
  , ("M-<Down>", windowGo D False)
  , ("M-k", prevWS)
  , ("M-j", nextWS)
  , ("M-<Tab>", toggleWS)
  , ("M-u", focusUrgent) -- jump to the window that asked for attention
  , -- move
    ("M-S-h", windowSwap L False)
  , ("M-S-l", windowSwap R False)
  , ("M-S-<Left>", windowSwap L False)
  , ("M-S-<Right>", windowSwap R False)
  , ("M-S-<Up>", windowSwap U False)
  , ("M-S-<Down>", windowSwap D False)
  , ("M-S-k", shiftToPrev >> prevWS)
  , ("M-S-j", shiftToNext >> nextWS)
  , ("M-S-<Return>", windows W.swapMaster)
  , -- windows
    ("M-S-c", kill)
  , ("M-t", toggleFloat)
  , ("M-f", layoutOsd $ sendMessage (Toggle NBFULL) >> sendMessage ToggleStruts)
  , ("M-m", layoutOsd $ sendMessage NextLayout)
  , ("M-<Space>", layoutOsd $ sendMessage NextLayout)
  , ("M-S-<Space>", layoutOsd $ asks (layoutHook . config) >>= setLayout)
  , ("M-g", toggleScreenSpacingEnabled >> toggleWindowSpacingEnabled)
  , ("M-[", sendMessage Shrink)
  , ("M-]", sendMessage Expand)
  , ("M-S-[", sendMessage MirrorShrink)
  , ("M-S-]", sendMessage MirrorExpand)
  , ("M-=", sendMessage (IncMasterN 1))
  , ("M--", sendMessage (IncMasterN (-1)))
  , -- screenshots / recording / tools
    -- (`grab`: wait a moment so the selection tools are not fighting the
    -- key that is still held down, or each other on key repeat)
    ("M-S-s", grab "shot region")
  , ("M-C-S-s", grab "flameshot gui || shot region")
  , ("<Print>", grab "shot region")
  , ("M-C-s", spawn "shot window")
  , ("M-S-r", grab "screenrec region")
  , ("M-C-r", spawn "screenrec output")
  , ("M-M1-r", grab "screenrec region audio")
  , ("M-p", grab "grabc 2>/dev/null | tr -d '\\n' | xclip -selection clipboard")
  , ("M-.", spawn "quickshell ipc call launcher emoji")
  , ("M-S-t", grab "ocr-clip")
  , ("M-S-a", spawn "pkill -x pw-loopback || pw-loopback")
  , -- media keys
    ("<XF86AudioRaiseVolume>", spawn "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+")
  , ("<XF86AudioLowerVolume>", spawn "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%-")
  , ("<XF86AudioMute>", spawn "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
  , ("<XF86AudioMicMute>", spawn "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
  , ("<XF86AudioPlay>", spawn "playerctl play-pause")
  , ("<XF86AudioNext>", spawn "playerctl next")
  , ("<XF86AudioPrev>", spawn "playerctl previous")
  , ("<XF86MonBrightnessUp>", spawn "brightnessctl set 5%+")
  , ("<XF86MonBrightnessDown>", spawn "brightnessctl set 5%-")
  ]
    -- monitors: focus / send the window to the screen in that direction
    ++ [ (m ++ k, f d False)
       | (k, d) <- dirs
       , (m, f) <- [("M-C-", screenGo), ("M-S-C-", \d' w -> windowToScreen d' w >> screenGo d' w)]
       ]
    -- workspaces: super+N shows N (again: back to the previous one),
    -- super+shift+N sends the window there
    ++ [ (m ++ ws, f ws)
       | ws <- myWorkspaces
       , (m, f) <- [("M-", toggleOrView), ("M-S-", windows . W.shift)]
       ]
  where
    dirs =
      [ ("h", L), ("l", R), ("k", U), ("j", D)
      , ("<Left>", L), ("<Right>", R), ("<Up>", U), ("<Down>", D)
      ]
    reload =
      "monitors; xmonad --recompile && xmonad --restart;"
        ++ " quickshell ipc call shell reload || setsid -f quickshell >/dev/null 2>&1"

-- selection tools (slop, maim -s, flameshot, grabc) grab the pointer and
-- keyboard; start them once the shortcut is released
grab :: String -> X ()
grab cmd = spawn ("sleep 0.25; " ++ cmd)

-- run a layout change, then show the new layout's name on screen
layoutOsd :: X () -> X ()
layoutOsd act = do
  act
  name <- gets (layoutName . W.workspace . W.current . windowset)
  spawn ("quickshell ipc call osd layout " ++ name)

-- "Spacing tall" -> "tall"; the fullscreen toggle reports "Full"
layoutName :: W.Workspace WorkspaceId (Layout Window) Window -> String
layoutName = maybe "" (map toLower) . listToMaybe . reverse . words . description . W.layout

toggleFloat :: X ()
toggleFloat = withFocused $ \w -> do
  floating <- gets (M.member w . W.floating . windowset)
  windows $
    if floating
      then W.sink w
      else W.float w (W.RationalRect 0.15 0.15 0.7 0.7)

-- super + drag: left moves, right resizes (xmonad default);
-- super + scroll switches workspaces
myMouse :: XConfig Layout -> M.Map (KeyMask, Button) (Window -> X ())
myMouse c =
  M.fromList
    [ ((mod4Mask, button4), const prevWS)
    , ((mod4Mask, button5), const nextWS)
    ]
    <> mouseBindings def c

-- ---- focus follows the mouse onto empty monitors -----------------------------
-- xmonad only changes screen when the pointer enters a window, so on an empty
-- monitor the focus (and every new window) stayed on the previous one. With
-- pointer motion selected on the root window (rootMask in main), moving over
-- the bare desktop of another monitor focuses that monitor.

screenUnderMouse :: Event -> X All
screenUnderMouse MotionEvent {ev_window = w, ev_x = x, ev_y = y} = do
  root <- asks theRoot
  when (w == root) $ do
    under <- pointScreen (fromIntegral x) (fromIntegral y)
    cur <- gets (W.screen . W.current . windowset)
    case under of
      Just s | W.screen s /= cur -> windows (W.view (W.tag (W.workspace s)))
      _ -> pure ()
  pure (All True)
screenUnderMouse _ = pure (All True)

-- ---- bar state ---------------------------------------------------------------
-- Published as JSON in the _XMONAD_LOG property of the root window on every
-- change; quickshell reads it with `xprop -spy` (quickshell/Xmonad.qml).
-- Everything outside printable ASCII is \u-escaped so xprop never mangles it.

barLog :: X ()
barLog = do
  ws <- gets windowset
  urgent <- readUrgents
  let shown = [(W.tag (W.workspace s), sid) | s <- W.screens ws, let S sid = W.screen s]
      order w = fromMaybe 99 (elemIndex (W.tag w) myWorkspaces)
      real = sortOn order [w | w <- W.workspaces ws, W.tag w /= scratchpadWorkspaceTag]
  wsJson <- forM real $ \w -> do
    let wins = W.integrate' (W.stack w)
    apps <- mapM (runQuery className) wins
    pure $
      obj
        [ ("name", jstr (W.tag w))
        , ("screen", show (fromMaybe (-1) (lookup (W.tag w) shown)))
        , ("urgent", jbool (any (`elem` urgent) wins))
        , ("apps", jarr (map jstr apps))
        ]
  (winTitle, winClass) <- case W.peek ws of
    Just w -> (,) <$> runQuery title w <*> runQuery className w
    Nothing -> pure ("", "")
  let S cur = W.screen (W.current ws)
      screen s =
        let Rectangle x y w h = screenRect (W.screenDetail s)
            S sid = W.screen s
         in obj
              [ ("id", show sid)
              , ("x", show x)
              , ("y", show y)
              , ("w", show w)
              , ("h", show h)
              , ("ws", jstr (W.tag (W.workspace s)))
              , ("layout", jstr (layoutName (W.workspace s)))
              ]
  xmonadPropLog' "_XMONAD_LOG" $
    obj
      [ ("focusedScreen", show cur)
      , ("title", jstr winTitle)
      , ("class", jstr winClass)
      , ("screens", jarr (map screen (W.screens ws)))
      , ("workspaces", jarr wsJson)
      ]

obj :: [(String, String)] -> String
obj kvs = "{" ++ intercalate "," [jstr k ++ ":" ++ v | (k, v) <- kvs] ++ "}"

jarr :: [String] -> String
jarr xs = "[" ++ intercalate "," xs ++ "]"

jbool :: Bool -> String
jbool b = if b then "true" else "false"

jstr :: String -> String
jstr s = "\"" ++ concatMap esc s ++ "\""
  where
    esc '"' = "\\\""
    esc '\\' = "\\\\"
    esc c
      | c >= ' ' && c < '\DEL' = [c]
      | ord c > 0xFFFF = let n = ord c - 0x10000 in u (0xD800 + n `div` 0x400) ++ u (0xDC00 + n `mod` 0x400)
      | otherwise = u (ord c)
    u :: Int -> String
    u = printf "\\u%04x"

-- ---- main --------------------------------------------------------------------

-- The session must not depend on how xmonad was started (startx with or
-- without ~/.xinitrc, a display manager, ...):
--  * ~/.local/bin (shot, screenrec, monitors, ...) goes on PATH for every
--    program xmonad starts
--  * without a session D-Bus (flameshot, notifications, the tray need it)
--    xmonad re-executes itself under dbus-run-session; a systemd user bus
--    ($XDG_RUNTIME_DIR/bus) counts as one
sessionEnv :: IO ()
sessionEnv = do
  home <- fromMaybe "" <$> lookupEnv "HOME"
  path <- fromMaybe "/usr/local/bin:/usr/bin:/bin" <$> lookupEnv "PATH"
  let bin = home ++ "/.local/bin"
  unless (bin `elem` splitPath path) $ setEnv "PATH" (bin ++ ":" ++ path)
  bus <- lookupEnv "DBUS_SESSION_BUS_ADDRESS"
  runtime <- lookupEnv "XDG_RUNTIME_DIR"
  userBus <- maybe (pure False) (doesPathExist . (++ "/bus")) runtime
  when (maybe True null bus && not userBus) $ do
    -- only returns if dbus-run-session is missing: carry on without a bus
    _ <- try (executeFile "dbus-run-session" True ["--", "xmonad"] Nothing) :: IO (Either SomeException ())
    pure ()
  where
    splitPath p = case break (== ':') p of
      (a, []) -> [a]
      (a, _ : rest) -> a : splitPath rest

main :: IO ()
main = do
  sessionEnv
  xmonad
      . ewmhFullscreen
      . ewmh
      . docks
      . withUrgencyHook NoUrgencyHook
      . withNavigation2DConfig def
      $ def
        { modMask = mod4Mask
        , terminal = "wezterm"
        , workspaces = myWorkspaces
        , borderWidth = 2
        , normalBorderColor = colBorder
        , focusedBorderColor = colFocused
        , focusFollowsMouse = True
        , clickJustFocuses = False
        , layoutHook = myLayout
        , manageHook = myManageHook
        , keys = (`mkKeymap` myKeys)
        , mouseBindings = myMouse
        , logHook = barLog
        , handleEventHook = screenUnderMouse
        , rootMask = rootMask def .|. pointerMotionMask
        , -- LG3D: Java (JetBrains etc.) draws grey windows under unknown WMs
          startupHook = do
            checkKeymap (def {modMask = mod4Mask}) myKeys
            setWMName "LG3D"
            spawn "\"$HOME/.config/xmonad/autostart\""
        }
