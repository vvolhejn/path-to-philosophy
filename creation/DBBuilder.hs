{-# LANGUAGE OverloadedStrings, LambdaCase, MultiWayIf #-} --, MultiWayIf, 

module DBBuilder where

import WikiParser
import BSUtil

import Database.Redis
import Network.CGI
import Data.Maybe
import Control.Monad
import qualified Data.ByteString.Char8 as BS

import Control.Concurrent.Async

type Id = BS.ByteString

phid :: Id
phid = "13692155" --22954 = plato

add :: Id -> Id -> Redis Bool
add prev new
	| new==phid = return True --puvodni clanek - nechceme pridavat
	| new=="-2" = return False --chyba - parsing
	| new=="-1" = return False --chyba - neexistujici clanek
	| otherwise = do
	let fullNew = BS.append "id:distance:" new
	(exists fullNew) >>= \case
		Left _ -> return False
		Right False -> do --pridavame nove
			dist <- get' $ "id:distance:" +++ prev
			set ("id:distance:" +++ new)
				(addOne dist)
			lpush "queue" [new]
			set ("id:prevmin:" +++ new) prev
			set ("id:prevmax:" +++ new) prev
			liftIO $ putStr "+"
			return True
			where
				addOne :: BS.ByteString -> BS.ByteString --yup
				addOne to = BS.pack $ show $
					(fromMaybe (-1) (BS.readInt to >>= return.fst))+1
		Right True -> do
			dist <- get' $ "id:distance:" +++ new
			dist' <- get' $ "id:distance:" +++ prev
			if toInt dist < (1 + toInt dist') then return True else do
				oMin <- get' $ "id:prevmin:" +++ new
				oMax <- get' $ "id:prevmax:" +++ new
				s <- get' $ "id:score:" +++ prev
				s0 <- get' $ "id:score:" +++ oMin
				s1 <- get' $ "id:score:" +++ oMax
				if toInt s < toInt s0 then do
					set ("id:prevmin:" +++ new) prev
					return ()
				else return ()
				if toInt s > toInt s1 then do
					set ("id:prevmax:" +++ new) prev
					return ()
				else return ()
				return True
			where toInt to =
				(fromMaybe (-1) (BS.readInt to >>= return.fst))

get' :: BS.ByteString -> Redis BS.ByteString
get' qs = get qs >>= \case
		Left _ -> return ""
		Right (Just s) -> return s

checkRecords :: Id -> Redis ()
checkRecords id = do
	(Right (Just bDist)) <- get "best:distance"
	(Right (Just dist)) <- get ("id:distance:" +++ id)
	if
		| dist < bDist -> return ()
		| dist > bDist -> do
			score <- getPathScore id
			improve id dist score
		| dist == bDist -> do
			(Right (Just bScore')) <- get "best:score"
			score <- getPathScore id
			let bScore = read $ BS.unpack bScore'
			if bScore <= score then return () else do
				improve id dist score
				return ()
	where
		improve id dist score = do
			set "best:id" id
			set "best:distance" dist
			set "best:score" $ (BS.pack . show) score
			return ()

getPathScore :: Id -> Redis Int --je nutne znat skore tohoto!
getPathScore id = do
	idPath id False >>= \case --vzdy chceme minimalni cestu
		Nothing -> return (-1)
		Just p -> do
			mapM getScore p >>= return.sum.tail
			where
				getScore :: Id -> Redis Int
				getScore id = do
					(Right (Just score)) <- get$"id:score:" +++ id
					return $ read $ BS.unpack score

prev :: Id -> Bool -> Redis (Maybe Id)
prev id maximize = if id==phid then return $ Just phid else do
	prev <- get (BS.append prefix id)
	return $ case prev of
	  	Left _ -> Nothing
	  	Right a -> a
	where prefix = "id:prev" +++
		(if maximize then "max" else "min") +++ ":"

idPath :: Id -> Bool -> Redis (Maybe [Id])
idPath id maximize = prev id maximize >>= \case
	Nothing	 -> return Nothing
	Just id' -> if id == id'
		then return $ Just [id]
		else (idPath id' maximize) >>= \x -> return $ x >>= Just . (id:)


--DATABASE ADVANCEMENT
next :: Redis (Maybe BS.ByteString)
next = do
	Right res <- rpop "queue"
	return res

expand :: Id -> [Id] -> Redis Bool
expand from links = do
	liftIO $ BS.putStrLn $
	 from +++ ": " +++ (BS.pack$show$length links) +++ " backlinks"
	set ("id:score:" +++ from) $BS.pack.show$length links
	ok <- mapM (add from) links >>= return.and
	{-if ok then do
		checkRecords from
	else return ()-}
	return ok

advance n = do
	conn <- connect defaultConnectInfo
	ad conn n
	where
	ad _ 0 = return ()
	ad conn n = runRedis conn $ do
		--liftIO $ print $ "Advancing " +++ (BS.pack.show$n)
		x <- next
		case x of
			Nothing -> return ()
			Just id -> do
				ok <- (liftIO $ getLinks id) >>= expand id
				if (not ok) then
					liftIO $ putStrLn $ "Error while expanding " ++ BS.unpack id
				else return ()
				liftIO $ ad conn (n-1)

expandLoop myName = do
	conn <- connect defaultConnectInfo
	go <- runRedis conn $ do
		exists "stop" >>= \case
			Left _ -> return False
			Right x -> if x then return False else do
					del ["stop"] --aby nebylo potreba klic mazat
					return True
	if go then do
		--na seznamu nezalezi - jen na delce
		--mapConcurrently (\_ -> advance 49) [1..5]
		advance 49
		putStrLn $ "x" ++ myName
		expandLoop myName
	else putStrLn $ "s" ++ myName

--concurrentExpand n = do
--	mapConcurrently (\x -> expandLoop$show x) [1..n]

--conEx = concurrentExpand 5

main = expandLoop ""