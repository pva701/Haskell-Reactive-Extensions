{-# LANGUAGE BangPatterns #-}
module Rx.Observable.Do where

import Control.Exception (SomeException)
import Rx.Observable.Types

doAction
  :: (a -> IO ())
     -> Observable s a
     -> Observable s a
doAction !action !source =
  newObservable $ \observer -> do
    subscribe
      source (\v -> action v >> onNext observer v)
             (onError observer)
             (onCompleted observer)
{-# INLINE doAction #-}

doOnCompleted
  :: IO ()
     -> Observable s a
     -> Observable s a
doOnCompleted !action !source =
  newObservable $ \observer ->
    subscribe
      source (onNext observer)
             (onError observer)
             (action >> onCompleted observer)
{-# INLINE doOnCompleted #-}

doOnError
  :: (SomeException -> IO ())
     -> Observable s a
     -> Observable s a
doOnError !action !source =
    newObservable $ \observer ->
      subscribe
        source
        (onNext observer)
        (\err -> action err >> onError observer err)
        (onCompleted observer)
{-# INLINE doOnError #-}
