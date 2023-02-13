require 'nokogiri'
require 'open-uri'
require_relative 'db'
require 'geocoder'

# 
# Set Up
# 
toc_url = "https://nuforc.org/webreports/ndxpost.html"

#
# Downloading
#

# Handle the main page
root_url = "https://nuforc.org/webreports/"
doc = Nokogiri::HTML(URI.open(toc_url))
doc.css('tr').each do |row|
  next if row.css('td').count != 2
  the_link          = row.css('td')[0].css('a')[0]
  the_url           = root_url + the_link['href']
  the_date_string   = the_link.inner_text
  the_count         = row.css('td')[1].inner_text.to_i
  # Find or create
  the_page = PostDatePage[the_url]
  next if the_page
  puts "Page not found, updating."
  # Get the page content
  the_content       = Nokogiri::HTML(URI.open(the_url))
  PostDatePage.create(
    url: the_url,
    post_date: Date.strptime(the_date_string, '%m/%d/%y'), # Example: 5/13/22
    count: the_count,
    contents: the_content.to_s
  )
  puts "Created record for #{the_url}"
end

# Get all the post_date_pages where `scape_complete` is false
PostDatePage.where(scrape_complete: false).each do |page|
  doc = Nokogiri::HTML(page.contents)
  doc.css('tbody tr').each do |row|
    # Get the data
    cells = row.css('td')
    the_url = root_url + cells[0].css('a')[0]['href']
    puts cells[0].inner_text
    date_occured  = ""
    if cells[0].inner_text =~ /\d{1,2}\/\d{1,2}\/\d{2}$/
      begin 
        date_occured = DateTime.strptime(cells[0].inner_text, '%m/%d/%y')
      rescue Date::Error => e
        "Bad Date: #{cells[0].inner_text}"
      end
    elsif cells[0].inner_text =~ /\d{1,2}\/\d{1,2}\/\d{2} \d{2}:\d{2}$/
      begin
        date_occured  = DateTime.strptime(cells[0].inner_text, '%m/%d/%y %H:%M') 
      rescue Date::Error => e
        "Bad Date: #{cells[0].inner_text}"
      end
    else
      puts "Bad Date: #{cells[0].inner_text}"
      next
    end
    puts date_occured
    city = cells[1].inner_text
    state = cells[2].inner_text
    country = cells[3].inner_text
    shape = cells[4].inner_text
    duration_string = cells[5].inner_text
    date_reported = Date.strptime(cells[7].inner_text, '%m/%d/%y')
    images_present = cells[8].inner_text == "Yes"
    # Check if exists
    the_event = SightingEvent[the_url]
    next if the_event
    puts "Creating event record for #{the_url}"
    SightingEvent.create(
      url: the_url, date_occured: date_occured, date_reported: date_reported,
      post_date_page_id: page.url, city: city, state: state, country: country,
      shape: shape, duration_string: duration_string, images_present: images_present
    )
  end
  page.update(scrape_complete: true)
end

# Pull the pages for each sighting
SightingEvent.where(contents: nil).each do |sighting|
  the_content = Nokogiri::HTML(URI.open(sighting.url))
  sighting.update(contents: the_content.to_s)
  puts "Downloading contents: #{sighting.url}"
end

# Parse the pages
SightingEvent.where(contents: nil).invert.where(parse_complete: false).each do |sighting|
  puts "Parsing #{sighting.url}"
  doc = Nokogiri::HTML(sighting.contents)
  tds = doc.css('td')
  next unless tds[0]
  characteristics_string = nil
  tds[0].children.each do |node|
    node.children.each do |child|
      if child.inner_text =~ /^Characteristics: /
        characteristics_string = child.inner_text.gsub('Characteristics: ', '')
        puts characteristics_string
      end
    end
  end
  description = tds[1].inner_text
  sighting.update(
    characteristics_string: characteristics_string,
    description: description,
    parse_complete: true
  )
end

SightingEvent.where(geocode_id: nil, country: "USA").each do |sighting|
  next unless sighting.city && sighting.state
  geo_string = "#{sighting.city}, #{sighting.state}"
  puts "Processing: #{geo_string}"

  # Try to find in the db
  existing_geocoded_sightings = SightingEvent.where(geocode_id: nil).invert.where(city: sighting.city, state: sighting.state, country: "USA")
  unless existing_geocoded_sightings.empty?
    geocode = existing_geocoded_sightings.first.geocode
    sighting.update(geocode_id: geocode.place_id)
    puts "Found existing geocode for: #{geo_string}"
    next
  end

  # Querying API
  results = Geocoder.search(geo_string)
  if results.empty?
    puts "No results found"
    sighting.update(geocode: empty_geocode)
    next
  end
  result = results.first
  
  # Find or create
  geocode = Geocode[result.place_id]
  if geocode
    puts "Geocode found: #{geocode.to_s}"
    sighting.update(geocode: geocode)
    next
  end
  
  
  # Create
  puts "Venue not found, creating: #{geo_string}."
  Geocode.create(
    place_id: result.place_id,
    osm_type: result.osm_type,
    osm_id: result.osm_id,
    lat: result.latitude,
    lon: result.longitude,
    display_name: result.display_name,
    county: result.county,
    state: result.state
  )
  sighting.update(geocode_id: result.place_id)

end