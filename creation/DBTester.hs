{-# LANGUAGE OverloadedStrings, LambdaCase #-}

module DBTester where

import DBBuilder
import WikiParser
import Database.Redis
import Network.CGI
import Data.Maybe
import qualified Data.ByteString.Char8 as BS
import System.Console.ANSI

--adapted from RosettaCode
colorStr :: ColorIntensity -> Color -> String -> IO ()
colorStr fgi fg str = do
  setSGR [SetColor Foreground fgi fg]
  putStr str
  setSGR []

paths :: String -> IO ()
paths name = do
	putStr "----Maximum path to "
	colorStr Vivid Yellow name
	putStrLn "----"
	path name True
	putStr "----Minimum path to "
	colorStr Vivid Cyan name
	putStrLn "----"
	path name False

path :: String -> Bool -> IO ()
path name maximize = do
	conn <- connect defaultConnectInfo
	runRedis conn $ do
		id <- getId $ BS.pack name
		x <- idPath id maximize
		case x of
			Nothing -> liftIO $ print "Not found"
			Just p -> do
				names <- (mapM getName p)-- >>= mapM BS.pack
				liftIO $ colorStr Vivid color $ BS.unpack $ BS.unlines $ names
	where
		color = if maximize then Yellow else Cyan

getId :: BS.ByteString -> Redis Id
getId name = do
	let qs = (BS.pack "name:id:" `BS.append` name)
	get qs >>= \case
		Left _ -> return "REQUEST ERROR"
		Right (Just id) -> return id
		Right Nothing -> do
			id <- liftIO $ toPageId name
			--updateName id name
			return id

getName :: Id -> Redis BS.ByteString
getName id = do
	let qs = (BS.pack "id:name:" `BS.append` id)
	get qs >>= \case
		Left _ -> return "REQUEST ERROR"
		Right (Just name) -> do
			updateName id name
			return name
		Right Nothing -> do
			name <- liftIO $ fromPageId id
			updateName id name
			return name

updateName :: Id -> BS.ByteString -> Redis ()
updateName id name = do
	let qs = (BS.pack "id:name:" `BS.append` id)
	let qs' = (BS.pack "name:id:" `BS.append` name)
	set qs name
	set qs' id
	return ()

--divne: 46706149