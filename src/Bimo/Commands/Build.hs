{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
-- | Build model or project

module Bimo.Commands.Build
    ( BuildOpts (..)
    , build
    ) where

import qualified Data.Text as T
import Data.List
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
import Bimo.Types.Config.Project
import Bimo.Types.Config.Model

import Bimo.Config
import Bimo.Project
import Bimo.Model

-- data BuildOpts
--     = BuildProject
--     | BuildModel
--     deriving Show

data BuildOpts = BuildProject | BuildModel
    deriving Show

build :: (MonadIO m, MonadThrow m, MonadMask m, MonadLogger m, MonadReader Env m)
      => BuildOpts
      -> m ()
build BuildProject = do
    pConf <- asks projectConfig
    curDir <- getCurrentDir
    p@Project{..} <- readProjectConfig $ curDir </> pConf
    modelsDir <- asks projectModelsDir

    logInfoN "Build project"

    maybe (return ()) (buildModels modelsDir) userModels
  where
    buildModels root models =
        mapM_ (\(UserModel n _ _ _ _) -> do
            name <- parseRelDir n
            let dir = root </> name
            withCurrentDir dir $ build BuildModel) models

build BuildModel = do
    mConf       <- asks modelConfig
    curDir      <- getCurrentDir
    Model{..}   <- readModelConfig $ curDir </> mConf

    name        <- parseRelFile modelName
    execDir     <- asks modelExec
    srcDir      <- asks modelSrc

    buildScript <- case (language, userBuildScript) of
        (_, Just script) -> do path <- parseRelFile script
                               return $ curDir </> path
        (Just lang, Nothing) -> getBuildScript lang

    libPaths    <- case (language, libs) of
        (Nothing, Just _) -> return libs
        (Just lang, Just libs') -> do paths <- getLibPaths lang libs'
                                      return $ Just paths
        (_, _) -> return Nothing

    files       <- maybe (return Nothing)
                         (mapM (\p -> do path <- parseRelFile p
                                         return $ srcDir </> path)
                          >=> return . Just) srcFiles

    let execFile = execDir </> name

    logInfoN $ T.concat [ "Build model \""
                        , T.pack modelName
                        , "\""
                        ]

    require <- maybe (return True) (`requireBuild` execFile) files
    if require
        then build' buildScript files execFile libPaths
        else logInfoN "Nothing to build"
  where
    requireBuild src dst = do
        exists <- doesFileExist dst
        if exists
            then do times <- mapM getModificationTime src
                    dstTime <- getModificationTime dst
                    return $ dstTime <= maximum times
            else return True
    build' script src dst libs = do
        let script' = fromAbsFile script
            srcFlag = case src of
                Nothing -> []
                Just src' ->
                    [ "-s"
                    , foldl' (++) "" $ intersperse ":" (map fromRelFile src')
                    ]
            dstFlag = [ "-d"
                      , fromRelFile dst
                      ]
            libFlag = case libs of
                Nothing -> []
                Just libs' ->
                    [ "-l"
                    , foldl' (++) "" $ intersperse ":" libs'
                    ]
            args = srcFlag ++ dstFlag ++ libFlag
            p = proc script' args

        logInfoN $ T.concat [ "Build script: "
                            , T.pack script'
                            , "\nBuild args:\n"
                            -- , T.intercalate "\n" $ map T.pack args
                            , T.pack $ show args
                            ]

        (ec, out, err) <- liftIO $ readCreateProcessWithExitCode p ""
        unless (ec == ExitSuccess) $ throwM $ ModelBuildFailure dst out err

data BuildException
    = ModelBuildFailure !(Path Rel File) !String !String

instance Exception BuildException

instance Show BuildException where
    show (ModelBuildFailure name out err) = concat
        [ "Failure when build model exec: " ++ show name ++ "\n"
        , "stdout: \n" ++ out ++ "\n"
        , "stderr: \n" ++ err ++ "\n"
        ]
