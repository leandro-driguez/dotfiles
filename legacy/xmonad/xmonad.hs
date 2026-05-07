import XMonad
import XMonad.Util.EZConfig
import qualified XMonad.StackSet as W
import XMonad.Hooks.ManageDocks (avoidStruts, manageDocks)
import XMonad.Layout.Spacing (spacing)
import XMonad.Hooks.EwmhDesktops (ewmh)

myWorkspaces = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20"]

main = do
    spawn "sh /home/leandro_driguez/.xmonad/keyboard.sh"
    xmonad $ ewmh def
        { terminal    = "alacritty"
        , modMask     = mod1Mask
        , manageHook  = manageDocks <+> manageHook def
        , layoutHook  = avoidStruts $ spacing 10 $ layoutHook def
        , workspaces  = myWorkspaces
        } `additionalKeys`
        ( [ ((mod1Mask, xK_t), spawn "alacritty")
          , ((mod1Mask, xK_f), spawn "rofi -show drun")
          , ((mod1Mask .|. shiftMask, xK_c), kill)
          , ((mod1Mask, xK_n), windows W.focusDown)
          , ((mod1Mask, xK_p), windows W.focusUp)
          , ((0, xK_Print), spawn "scrot '/home/leandro_driguez/Pictures/Screenshots/%Y-%m-%d-%H%M%S_$wx$h.png'")
          , ((mod1Mask .|. shiftMask, xK_Print), spawn "scrot -s '/home/leandro_driguez/Pictures/Screenshots/%Y-%m-%d-%H%M%S_$wx$h.png'")
          ] ++
          [ ((m .|. mod1Mask, k), windows $ f i)
          | (i, k) <- zip myWorkspaces ([xK_1 .. xK_9] ++ [xK_0] ++ [xK_F1 .. xK_F10])
          , (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]
          ]
        )

