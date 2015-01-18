{-# LANGUAGE RankNTypes #-}
module Rx.Observable.Zip where

import Prelude hiding (zip, zipWith)

import Data.Monoid (mappend)

import Control.Concurrent (yield)
import Control.Concurrent.STM (TQueue, atomically, isEmptyTQueue, modifyTVar,
                               newTQueueIO, newTVarIO, readTQueue, readTVar,
                               writeTQueue, writeTVar)
import Control.Monad (unless, when)

import Rx.Disposable (setDisposable, toDisposable)
import Rx.Scheduler (Async)

import Rx.Observable.Types


zipWith :: (IObservable source1, IObservable source2)
        => (a -> b -> c)
        -> source1 Async a
        -> source2 Async b
        -> Observable Async c
zipWith zipFn source1 source2 = Observable $ \observer -> do
    queue1 <- newTQueueIO
    queue2 <- newTQueueIO

    isCompletedVar <- newTVarIO False
    completedCountVar <- newTVarIO (0 :: Int)

    main observer
         queue1 queue2
         isCompletedVar completedCountVar
  where
    next :: forall a . TQueue a -> IO a
    next = atomically . readTQueue

    conj :: forall a . TQueue a -> a -> IO ()
    conj queue a = atomically $ writeTQueue queue a
    isEmpty = isEmptyTQueue

    main observer
         queue1 queue2
         isCompletedVar completedCountVar = do

        disposableA <-
          subscribe source1 onNextA
                            onError_
                            onCompleted_

        disposableB <-
          subscribe source2 onNextB
                            onError_
                            onCompleted_

        return $ disposableB `mappend` disposableA
      where
        whileNotCompleted action = do
          wasCompleted <- atomically $ readTVar isCompletedVar
          unless wasCompleted $ action

        isAnyQueueEmpty = atomically $ do
          q1IsEmpty <- isEmpty queue1
          q2IsEmpty <- isEmpty queue2
          return $ q1IsEmpty || q2IsEmpty

        emptyQueues = do
          anyQueueEmpty <- isAnyQueueEmpty
          unless anyQueueEmpty $ do
            onNext_
            emptyQueues

        onNext_ = do
          anyQueueEmpty <- isAnyQueueEmpty
          unless anyQueueEmpty $ do
            val1 <- next queue1
            val2 <- next queue2
            onNext observer $ zipFn val1 val2

        onNextA a = whileNotCompleted $ do
          yield
          conj queue1 a
          onNext_

        onNextB b = whileNotCompleted $ do
          conj queue2 b
          onNext_

        onError_ err = whileNotCompleted $ do
          onError observer err

        onCompleted_ = whileNotCompleted $ do
          completedCount <- atomically $ do
            modifyTVar completedCountVar succ
            readTVar completedCountVar

          when (completedCount == 2) $ do
            atomically $ writeTVar isCompletedVar True
            emptyQueues
            onCompleted observer

zip :: (IObservable source1, IObservable source2)
       => source1 Async a
       -> source2 Async b
       -> Observable Async (a,b)
zip = zipWith (\a b -> (a, b))
