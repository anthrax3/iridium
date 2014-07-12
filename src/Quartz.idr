module Main

import IR
import IR.Event
import IR.Layout
import IR.Lens
import IR.Workspace

%flag C "-framework Cocoa"
%include C "cbits/quartz.h"
%link C "src/quartz.o"
%include C "cbits/ir.h"
%link C "src/ir.o"

%default total

%assert_total
putErrLn : String -> IO ()
putErrLn s = fwrite stderr (s ++ "\n")

quartzInit : IO Bool
quartzInit = map (/= 0) (mkForeign (FFun "quartzInit" [] FInt))

quartzSpacesCount : IO Int
quartzSpacesCount = mkForeign (FFun "quartzSpacesCount" [] FInt)

QuartzWindow : Type
QuartzWindow = Int

QuartzSpace : Type
QuartzSpace = Int

QuartzState : Type
QuartzState = IRState QuartzWindow QuartzSpace

QUARTZ : EFFECT
QUARTZ = IR QuartzWindow QuartzSpace

quartzGetWindows : IO (List QuartzWindow)
quartzGetWindows = do
  p <- mkForeign (FFun "quartzWindows" [] FPtr)
  l <- mkForeign (FFun "quartzWindowsLength" [FPtr] FInt) p
  wids <- traverse (\a => mkForeign (FFun "quartzWindowId" [FPtr, FInt] FInt) p a) [0..l-1]
  mkForeign (FFun "quartzWindowsFree" [FPtr] FUnit) p
  return wids

quartzTileWindow : QuartzWindow -> Rectangle -> IO ()
quartzTileWindow wid r =
  mkForeign (FFun "quartzWindowSetRect" [FInt, FFloat, FFloat, FFloat, FFloat] FUnit) wid (rectX r) (rectY r) (rectW r) (rectH r)

quartzFocusWindow : QuartzWindow -> IO ()
quartzFocusWindow wid =
  mkForeign (FFun "quartzWindowSetFocus" [FInt] FUnit) wid

quartzRefresh : QuartzState -> IO QuartzState
quartzRefresh s = do
  wids <- quartzGetWindows
  let workspace : Workspace QuartzWindow = foldr manage (MkWorkspace (workspaceLayout' . screenWorkspace' . stackSetCurrent' . irStateStackSet' ^$ s) Nothing) wids
  return (screenWorkspace' . stackSetCurrent' . irStateStackSet' ^= workspace $ s)

quartzGetFrames : IO (n ** Vect (S n) Rectangle)
quartzGetFrames = do
  p <- mkForeign (FFun "quartzMainFrame" [] FPtr)
  x <- mkForeign (FFun "irFrameX" [FPtr] FFloat) p
  y <- mkForeign (FFun "irFrameY" [FPtr] FFloat) p
  w <- mkForeign (FFun "irFrameW" [FPtr] FFloat) p
  h <- mkForeign (FFun "irFrameH" [FPtr] FFloat) p
  mkForeign (FFun "irFrameFree" [FPtr] FUnit) p
  return (0 ** [MkRectangle x y w h])

instance Handler (IREffect QuartzWindow QuartzSpace) IO where
  handle () GetEvent k = do
    p <- mkForeign (FFun "quartzEvent" [] FPtr)
    e <- eventFromPtr p
    k e ()
  handle () (GrabKeys keys) k = do
    -- TODO: ignore these keys
    k () ()
  handle () (RefreshState s) k = do
    s' <- quartzRefresh s
    k s' ()
  handle () (TileWindow wid r) k = do
    quartzTileWindow wid r
    k () ()
  handle () (SetFocus wid) k = do
    quartzFocusWindow wid
    k () ()
  handle () GetWindows k = do
    wids <- quartzGetWindows
    k wids ()
  handle () GetFrames k = do
    f <- quartzGetFrames
    k f ()

initialQuartzState : IO (IRState QuartzWindow QuartzSpace)
initialQuartzState = do
  (_ ** frame :: _) <- quartzGetFrames
  wids <- quartzGetWindows
  let workspace : Workspace QuartzWindow = foldr manage (MkWorkspace (choose [columnLayout, mirrorLayout columnLayout, fullLayout]) Nothing) wids
  return (MkIRState (MkStackSet (MkScreen workspace 0 frame) [] []))

quartzConf : IRConf QuartzWindow QuartzSpace
quartzConf =
  MkIRConf (fromList [
    (MkKey 49 True True False False, update nextLayout >>= \_ => refresh)
  , (MkKey 38 True True False False, windows focusDown)
  ])

partial
main : IO ()
main = do
  putStrLn "iridium started"
  a <- quartzInit
  if not a
  then do
    putErrLn "iridium doesn't have Accessibility permission."
    putErrLn "You can enable this under Privacy in Security & Privacy in System Preferences."
  else runInit [(), !initialQuartzState, quartzConf] runIR
