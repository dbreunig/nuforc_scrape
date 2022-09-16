# NUFORC Scrape

A simple ruby script for scraping the [NUFORC](https://nuforc.org/) UFO reporting database.

The script does the following:

1. Creates a sqlite database and associated tables, if they don't already exist.
2. Grabs the [sightings by date](https://nuforc.org/webreports/ndxevent.html) page then downloads and parses each available page.
3. Walks throughe each parsed page and downloads each associated event page.
4. Walks through the contents of each page and parses the appropriate metadata.
5. Attempts to geocodes the location, if possible, for each sighting event.

In each step, the script downloads and caches the HTML for each page. Subsequent runs of the script will not redownload or reparse data if there is no need to.
