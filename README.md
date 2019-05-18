# RSS-Feed-Proxy

Powershell script to create a local proxy for RSS feeds of yts.am and rarbg.to to filter out duplicate movies.
The scripts extract the movie quality from the torrent name and keep only the torrent with the best quality, all other torrents are removed from the feed, so that a movie isn't downloaded many times.

The script uses Polaris to create the RSS feed proxy and it is meant to be run as a service with NSSM. 
