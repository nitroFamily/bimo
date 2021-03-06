module Bimo.Types.Env where

import Path

data Env = Env
    { -- | Specify app name
      appDir :: !(Path Abs Dir)
      -- | Project dirs and config
    , projectConfig    :: !(Path Rel File)
    , projectModelsDir :: !(Path Rel Dir)
      -- | Model dir and config
    , modelSrc    :: !(Path Rel Dir)
    , modelExec   :: !(Path Rel Dir)
    , modelConfig :: !(Path Rel File)
      -- | Models dir
    , modelsDir     :: !(Path Abs Dir)
      -- | Templates dir
    , templatesDir  :: !(Path Abs Dir)
      -- | Build scripts dir
    , buildScriptsDir :: !(Path Abs Dir)
    , libsDir         :: !(Path Abs Dir)
    -- , templatesConfig :: !FilePath
      -- | Temp folder to run models
    , runDir :: !String
    }
