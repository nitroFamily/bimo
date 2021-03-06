import TestLib
import System.Directory

main :: IO ()
main = do
    -- Add valid template
    bimo ["build"]
    bimo ["add", "-t", "new-template"]

    -- Create new project and run
    bimo ["new", "-p", "new-project", "-t", "new-template"]
    setCurrentDirectory "new-project"
    doesExist "models"
    bimo ["run"]

