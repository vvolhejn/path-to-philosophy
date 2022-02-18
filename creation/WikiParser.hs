{-# LANGUAGE OverloadedStrings, LambdaCase #-}

module WikiParser where

import BSUtil
import Data.List
import Data.List.Split
import Data.Maybe
import Data.Char
import System.IO.Streams (InputStream, OutputStream, stdout)
import qualified System.IO.Streams as Streams
import qualified Data.ByteString.Char8 as BS
import Data.ByteString.Search (split)
import Network.Http.Client
import Network.HTTP (urlEncode)

parseLine :: BS.ByteString -> BS.ByteString
parseLine "" = "-2" -- "-1" pouziva wikipedicke API
parseLine l
	| toFind `BS.isPrefixOf` l = BS.takeWhile (','/=) $ BS.drop (BS.length toFind) l
	| otherwise				= parseLine
 $ BS.tail l
	where toFind = "\"pageid\":"

parseJson = Data.ByteString.Search.split "},{"

getLinks :: BS.ByteString -> IO [BS.ByteString]
getLinks pageid = getLinks' pageid Nothing
	where
	getLinks' pageid from = do
		let link = case from of
			Nothing -> linkTo pageid
			Just f -> linkTo pageid +++ "&blcontinue=" +++ f

		input' <- readFrom link
		let input = parseJson input'
		if "[]" `BS.isInfixOf` (head input) then return [] --nejsou backlinky
		else do
			--putStr $ if from==Nothing then "\t" else "." --vizualizace veikosti
			let cont = continue $ head $ input
			theRest <- if cont /= Nothing then (getLinks' pageid cont) else (return [])
			let ids = (map parseLine $ input)
			return $ ids ++ theRest
	continue :: BS.ByteString -> Maybe BS.ByteString
	continue s
		| rest == "" = Nothing
		| otherwise = Just . toUrl . (BS.takeWhile ('"'/=)) . (BS.drop 3) $ rest
		where
			rest = dropToPrefix "blcontinue" s

linkTo s = apiLink +++ s

apiLink :: BS.ByteString
apiLink = "http://en.wikipedia.org/w/api.php?action=query&\
\list=backlinks&format=json&bllimit=500&blfilterredir=nonredirects&blnamespace=0&utf8=true&blpageid="
--Đuro Kurepa

fromPageId :: BS.ByteString -> IO BS.ByteString
fromPageId id = do
	--putStrLn "<fromPageId>"
	input <- readFrom $ fplinkTo id
	return $ BS.takeWhile ('"'/=) $ dropToPrefix "title\":\"" $ dropToPrefix "pages" input

fplinkTo x = "http://en.wikipedia.org/w/api.php?action=query&prop=pageprops&format=json&pageids=" +++ x

toPageId :: BS.ByteString -> IO BS.ByteString
toPageId id = do
	--putStrLn "<toPageId>"
	input <- readFrom $ tplinkTo id
	return. BS.takeWhile ('"'/=) $ BS.drop 4 $ dropToPrefix "pages" input

tplinkTo x = "http://en.wikipedia.org/w/api.php?action=query&prop=pageprops&format=json&titles="
	+++ (toUrl x)
	
dropToPrefix :: BS.ByteString -> BS.ByteString -> BS.ByteString
dropToPrefix _ "" = ""
dropToPrefix toFind l
	| toFind `BS.isPrefixOf` l = BS.drop (BS.length toFind) l
	| otherwise				= dropToPrefix toFind (BS.tail l)

toUrl = BS.pack.urlEncode.BS.unpack

readFrom :: URL -> IO BS.ByteString
readFrom url = do
	a <- get url
		(\p i -> Streams.takeBytesWhile (\_->True) i)
	return $ fromMaybe "" a
