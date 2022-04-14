# Path to Philosophy

This is a project from around 2015 that I am now dusting off to preserve here on GitHub.
Currently, it doesn't work - possibly because the major versions of Node, GHC or Redis that came out in the meanwhile broke something.

It's a webapp into which you can input any Wikipedia article and it will tell you
what the fewest number of clicks you need to get from that article to [Philosophy](https://en.wikipedia.org/wiki/Philosophy).
It's a crossover between [Five Clicks to Hitler](https://en.wikipedia.org/wiki/Wikipedia:Wiki_Game)
and [Getting to Philosophy](https://en.wikipedia.org/wiki/Wikipedia:Getting_to_Philosophy).

There is a Haskell backend that does breadth-first search on the links graph using the Wikipedia API.
This backend populates a Redis database that specifies which article to go to next.
Then there is a Node frontend that provides a user interface and reads the database to find a path from the article to Philosophy.
