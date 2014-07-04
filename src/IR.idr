module IR

import Effect.State
import IR.Event

%default total

record Rectangle : Type where
  MkRectangle : (rectX : Float) ->
                (rectY : Float) ->
                (rectW : Float) ->
                (rectH : Float) ->
                Rectangle

record Stack : Type -> Type where
  MkStack : (stackFocus : wid) ->
            (stackUp : List wid) ->
            (stackDown : List wid) ->
            Stack wid

record Workspace : Type -> Type where
  MkWorkspace : (workspaceStack : Maybe (Stack wid)) ->
                Workspace wid

record Screen : Type -> Type -> Type where
  MkScreen : (screenWorkspace : Workspace wid) ->
             (screenId : sid) ->
             (screenDetail : Rectangle) ->
             Screen wid sid

record StackSet : Type -> Type -> Type where
  MkStackSet : (stackSetCurrent : Screen wid sid) ->
               (stackSetVisible : List (Screen wid sid)) ->
               (stackSetHidden  : List (Workspace wid)) ->
               StackSet wid sid

record IRState : Type -> Type -> Type where
  MkIRState : (irStateStackSet : StackSet wid sid) ->
              IRState wid sid

data IREffect : Type -> Type -> Effect where
  GetEvent : { () } (IREffect wid sid) Event
  HandleEvent : IRState wid sid -> Event -> { () } (IREffect wid sid) (IRState wid sid)
  GetFrames : { () } (IREffect wid sid) (n ** Vect (S n) Rectangle)
  GetWindows : { () } (IREffect wid sid) (List wid)
  TileWindow : wid -> Rectangle -> { () } (IREffect wid sid) ()

IR : Type -> Type -> EFFECT
IR wid sid = MkEff () (IREffect wid sid)

getEvent : { [IR wid sid] } Eff e Event
getEvent = call GetEvent

handleEvent : IRState wid sid -> Event -> { [IR wid sid] } Eff e (IRState wid sid)
handleEvent s e = call (HandleEvent s e)

getFrames : { [IR wid sid] } Eff e (n ** Vect (S n) Rectangle)
getFrames = call GetFrames

getWindows : { [IR wid sid] } Eff e (List wid)
getWindows = call GetWindows

tileWindow : wid -> Rectangle -> { [IR wid sid] } Eff e ()
tileWindow wid rect = call (TileWindow wid rect)

partial
runIR : { [IR wid sid, STATE (IRState wid sid)] } Eff IO ()
runIR = do
  e <- getEvent
  s <- get
  s' <- handleEvent s e
  put s'
  runIR
