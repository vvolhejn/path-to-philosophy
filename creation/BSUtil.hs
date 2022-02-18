module BSUtil where

import qualified Data.ByteString.Char8 as BS

(+++) :: BS.ByteString -> BS.ByteString -> BS.ByteString
(+++) a b = a `BS.append` b