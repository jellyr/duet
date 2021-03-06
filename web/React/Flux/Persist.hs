{-# LANGUAGE CPP, BangPatterns, TypeFamilies, DeriveGeneric, DeriveAnyClass, OverloadedStrings, LambdaCase, TupleSections, ExtendedDefaultRules, FlexibleContexts, ScopedTypeVariables, DeriveDataTypeable #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}

-- |

module React.Flux.Persist where

import Control.Concurrent
import Control.Exception
import Data.Aeson
import Data.Aeson.Types
import Data.JSString
import Duet.Types (UUID(..))
import GHCJS.Marshal (FromJSVal(..), ToJSVal(..), toJSVal_aeson)
import GHCJS.Types (JSVal, JSString)

#if __GHCJS__
foreign import javascript unsafe
    "(function(){ if (sessionStorage.getItem($1)) return JSON.parse(sessionStorage.getItem($1)); })()"
    js_sessionStorage_getItemVal :: JSString -> IO JSVal

foreign import javascript unsafe
    "sessionStorage.setItem($1,JSON.stringify($2));"
    js_sessionStorage_setItemVal :: JSString -> JSVal -> IO ()
#endif

-- | Get the app state.
getAppStateVal :: FromJSON a => IO (Maybe a)
getAppStateVal = do
  jv <- js_sessionStorage_getItemVal "app-state"
  value <- fromJSVal jv
  evaluate (value >>= parseMaybe parseJSON)
  where
    eitherToMaybe = either (const Nothing) Just

-- | Set the app state.
setAppStateVal
  :: ToJSON a
  => a -> IO ()
setAppStateVal app = do
  _ <-
    forkIO
      (do !val <- toJSVal_aeson app
          js_sessionStorage_setItemVal "app-state" val)
  return ()

#if __GHCJS__
foreign import javascript unsafe "window['generateUUID']()"
    js_generateUUID :: IO JSString
#endif

#if __GHCJS__
foreign import javascript unsafe "window['resetUUID']()"
    js_resetUUID :: IO ()
#endif

resetUUID :: IO ()
resetUUID = js_resetUUID

generateUUID :: IO UUID
generateUUID = UUID . unpack <$> js_generateUUID
