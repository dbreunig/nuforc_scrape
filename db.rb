#
# Database
# 
require 'sequel'
require 'h3'
DB = Sequel.sqlite('nuforc.db')

# Each represents an individual link on the `toc_url`
# Page is cached in `contents`
DB.create_table?(:post_date_pages) do
  String :url,              primary_key: true
  Date :post_date,          null: false
  Integer :count,           null: false
  Boolean :scrape_complete, default: false
  String :contents, text: true
end

class PostDatePage < Sequel::Model 
  one_to_many :sighting_events
end
PostDatePage.unrestrict_primary_key

# Unprocessed webpage is stored in `contents`
DB.create_table?(:sighting_events) do
  String :url, primary_key: true
  foreign_key :post_date_page_id, :post_date_pages, type: 'varchar(255)'
  DateTime :date_occured
  Date :date_reported
  String :city
  String :state
  String :country
  String :shape
  String :duration_string
  String :characteristics_string
  String :description, text: true
  Boolean :parse_complete, default: false
  Boolean :images_present, default: false
  String :contents, text: true
end

# The geocoder result
DB.create_table?(:geocodes) do
  Bignum :place_id, primary_key: true
  Bignum :osm_id
  String :osm_type
  Float  :lat
  Float  :lon
  String :display_name
  String :state
  String :county
end

unless DB[:sighting_events].columns.index(:geocode_id)
  DB.alter_table(:sighting_events) do
    add_foreign_key :geocode_id, :geocodes
  end
end

class Geocode < Sequel::Model 
  one_to_many :sighting_events

  def to_h3(resolution)
    H3.from_geo_coordinates([lat, lon], resolution).to_s(16)
  end
end
Geocode.unrestrict_primary_key

class SightingEvent < Sequel::Model 
  many_to_one :post_date_page
  many_to_one :geocode, key: :geocode_id
end
SightingEvent.unrestrict_primary_key

def empty_geocode
  empty_code = Geocode[666]
  unless empty_code
    Geocode.create(
      place_id: 666,
      display_name: "No results",
    )
  end
  empty_code
end