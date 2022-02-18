{-# LANGUAGE OverloadedStrings #-}

import System.IO.Streams (InputStream, OutputStream, stdout)
import qualified System.IO.Streams as Streams
import qualified Data.ByteString.Char8 as BS
import Network.Http.Client
import Data.Maybe

readFrom :: URL -> IO BS.ByteString
readFrom url = do
	a <- get url
		(\p i -> Streams.takeBytesWhile (\_->True) i)
	return $ fromMaybe "" a

t = readFrom "http://example.com"