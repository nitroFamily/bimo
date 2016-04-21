{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE FlexibleContexts #-}
-- | Build model or project

module Bimo.Build
    ( BuildOpts (..)
    , build
    ) where

import Control.Monad
import Control.Monad.Reader
import Control.Monad.Logger
import Control.Monad.Catch
import Control.Monad.IO.Class
import Path
import Path.IO
import System.Process
import System.Exit

import Bimo.Types.Env
-- import Bimo.Types.Config.Project
import Bimo.Types.Config.Model

import Bimo.Config

data BuildOpts
    = BuildProject
    | BuildModel
    deriving Show

build :: (MonadIO m, MonadThrow m, MonadLogger m, MonadReader Env m)
      => BuildOpts
      -> m ()
-- build BuildProject = do
build BuildModel = do
    Env{..} <- ask
    exists <- doesFileExist modelConfig
    unless exists $ throwM $ NotFoundModelConfig modelConfig
    m <- readModelConfig modelConfig
    script <- getBuildScript $ language m

    let srcDir = fromRelDir modelSrc
        dstDir = fromRelDir modelExec
        src = srcFile m
        dst = modelName m
        p = proc (fromAbsFile script) [srcDir ++ src, dstDir ++ dst]

    (ec, out, err) <- liftIO $ readCreateProcessWithExitCode p ""
    unless (ec == ExitSuccess) $ throwM $ ModelBuildFailure out err

data BuildException
    = NotFoundModelConfig !(Path Rel File)
    | ModelBuildFailure !String !String
    deriving (Show)

instance Exception BuildException
