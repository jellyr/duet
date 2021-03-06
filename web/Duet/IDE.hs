{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE BangPatterns, TypeFamilies, DeriveGeneric, DeriveAnyClass, OverloadedStrings, LambdaCase, TupleSections, ExtendedDefaultRules, FlexibleContexts, ScopedTypeVariables, DeriveDataTypeable #-}
{-# OPTIONS_GHC -fno-warn-orphans -fno-warn-type-defaults #-}

module Duet.IDE where

import           Control.Concurrent
import           Control.Monad.Catch
import           Control.Monad.State (execStateT)
import           Control.Monad.Supply
import           Data.Bifunctor
import qualified Data.Map.Strict as M
import           Data.Typeable
import           Duet.Context
import           Duet.Errors
import           Duet.IDE.Interpreters
import           Duet.IDE.Types
import           Duet.Infer
import           Duet.Resolver
import           Duet.Types
import           React.Flux (ReactStore, SomeStoreAction)
import qualified React.Flux as Flux
import qualified React.Flux.Persist as Flux.Persist
import           Shared

--------------------------------------------------------------------------------
-- Store setup

-- | Dispatch an action on the store.
dispatch :: Action -> SomeStoreAction
dispatch a = Flux.SomeStoreAction store a

-- | The app's model.
store :: ReactStore State
store = do
  Flux.mkStore
    initState

-- | Initial state of the app.
initState :: State
initState = makeState initName initExpression

initName :: String
initName = "_"

initExpression :: forall (t :: * -> *) i. Expression t i Label
initExpression =
  (ConstantExpression (Label {labelUUID = starterExprUUID}) (Identifier "_"))

starterExprUUID :: UUID
starterExprUUID = UUID "STARTER-EXPR"

makeState :: String -> Expression UnkindedType Identifier Label -> State
makeState ident expr =
  State
  { stateCursor = Cursor {cursorUUID = uuidI}
  , stateTypeCheck = Right ()
  , stateHighlightErrors = mempty
  , stateAST =
      ModuleNode
        (Label (UUID "STARTER-MODULE"))
        [ BindDecl
            (Label {labelUUID = uuidD})
            (ImplicitBinding
               (ImplicitlyTypedBinding
                { implicitlyTypedBindingLabel =
                    Label (UUID "STARTER-BINDING")
                , implicitlyTypedBindingId = (Identifier ident, Label uuidI)
                , implicitlyTypedBindingAlternatives =
                    [ Alternative
                      { alternativeLabel =
                          Label (UUID "STARTER-ALT")
                      , alternativePatterns = []
                      , alternativeExpression = expr
                      }
                    ]
                }))
        ]
  }
  where
    uuidD = UUID "STARTER-DECL"
    uuidI = UUID "STARTER-BINDING-ID"

--------------------------------------------------------------------------------
-- Model

instance Flux.StoreData State where
  type StoreAction State = Action
  transform action state = do
    state' <- execStateT (interpretAction action) state
    _ <- forkIO (Flux.Persist.setAppStateVal state')
    result <-
      catch
        (fmap
           (Right . const ())
           (evalSupplyT
              (do (binds, context) <-
                    createContext
                      (case stateAST state' of
                         ModuleNode _ ds -> ds
                         _ -> [])
                  pure (binds, context))
              [1 ..]))
        (\e@(ContextException {}) -> pure (Left e))
    pure
      state'
      { stateTypeCheck = bimap displayException id result
      , stateHighlightErrors =
          case result of
            Left (ContextException _ (SomeException (cast -> Just (IdentifierNotInVarScope _scope _i l)))) ->
              M.singleton (labelUUID l) "unknown variable"
            _ -> mempty
      }

--------------------------------------------------------------------------------
-- Context setup

data ContextException = ContextException (SpecialTypes Name) SomeException
  deriving (Show, Typeable)

instance Exception ContextException where
  displayException (ContextException specialTypes (SomeException se)) =
    maybe
      (maybe
         (maybe
            (maybe
               (maybe
                  (displayException se)
                  (("Renaming problem:\n" ++) . displayRenamerException specialTypes)
                  (cast se))
               (("Type checking problem:\n" ++) . displayInferException specialTypes)
               (cast se))
            (("Stepping problem:\n" ++) . displayStepperException specialTypes)
            (cast se))
         (("Instance resolving problem:\n" ++) . displayResolveException specialTypes)
         (cast se))
      displayParseException
      (cast se)

-- | Create a context of all renamed, checked and resolved code.
createContext
  :: (MonadSupply Int m, MonadCatch m)
  => [Decl UnkindedType Identifier Label]
  -> m ([BindGroup Type Name (TypeSignature Type Name Label)], Context Type Name Label)
createContext decls = do
  do builtins <-
       setupEnv mempty [] >>=
       traverse
         (const (pure (Label {labelUUID = UUID "<GENERATED>"})))
     let specials = builtinsSpecials builtins
     catch
       (do (typeClasses, signatures, renamedBindings, scope, dataTypes) <-
             renameEverything decls specials builtins
           -- Type class definition
           addedTypeClasses <- addClasses builtins typeClasses
               -- Type checking
           (bindGroups, typeCheckedClasses) <-
             typeCheckModule
               addedTypeClasses
               signatures
               (builtinsSpecialTypes builtins)
               renamedBindings
           -- Type class resolution
           resolvedTypeClasses <-
             resolveTypeClasses
               typeCheckedClasses
               (builtinsSpecialTypes builtins)
           resolvedBindGroups <-
             mapM
               (resolveBindGroup
                  resolvedTypeClasses
                  (builtinsSpecialTypes builtins))
               bindGroups
           -- Create a context of everything
           let context =
                 Context
                 { contextSpecialSigs = builtinsSpecialSigs builtins
                 , contextSpecialTypes = builtinsSpecialTypes builtins
                 , contextSignatures = signatures
                 , contextScope = scope
                 , contextTypeClasses = resolvedTypeClasses
                 , contextDataTypes = dataTypes
                 }
           pure (resolvedBindGroups, context))
       (throwM . ContextException (builtinsSpecialTypes builtins))
