# https://datatracker.ietf.org/doc/html/draft-daboo-icalendar-extensions
require 'httparty'
require 'nokogiri'
require 'json'

response = HTTParty.get('https://tickets.thefoat.com/lasvegascarmeets/host_id-110971/')
if response.code != 200
  raise "Error: #{response.code}"
end
doc = Nokogiri::HTML(response.body)


puts "BEGIN:VCALENDAR"
puts "NAME:Las Vegas Car Scene Network Events"
puts "VERSION:2.0"
puts "PRODID:https://github.com/ukd1/las-vegas-car-scene-network-ical"
puts "DESCRIPTION:Las Vegas Car Scene Network Events, parsed from https://tickets.thefoat.com/lasvegascarmeets/host_id-110971/. Code @ https://github.com/ukd1/las-vegas-car-scene-network-ical."
puts "UID:https://github.com/ukd1/las-vegas-car-scene-network-ical"
puts "URL:https://github.com/ukd1/las-vegas-car-scene-network-ical"
puts "SOURCE;VALUE=URI:https://raw.githubusercontent.com/ukd1/las-vegas-car-scene-network-ical/main/las-vegas-car-scene-network-events.ics"
puts "IMAGE;VALUE=URI;DISPLAY=BADGE;FMTTYPE=image/png:https://tickets.thefoat.com/images/tb/hosts/banner_img_16740224611ad95f.png"

event_by_id = {}
locations_by_url = {}

doc.css('#items-container div.tb-item').each do |item|
  id = item.css('.alert-me-event').attribute('data-event_id')&.value
  name = item.css('.tb-item-info h3').text.split('-').first.strip
  date = item.css('.date span').text.split(' ').last.strip
  url = item.css('.btn-success').attribute('href')&.value || item.css('.alert-me-event').attribute('href')&.value

  dtstart = Date.strptime(date, '%m/%d/%Y')
  dtend = dtstart+1

  # some events don't actually have an ID...?
  id = "#{id}-#{url}"

  location = item.css('.tb-item-info a').last.attribute('href')&.value
  locations_by_url[location] ||= {}

  event_by_id[id] ||= {
    url: url,
    name: name,
    id: id,
    dtstart: dtstart,
    dtend: dtend,
    location: location,
  }

  event_by_id[id][:dtend] = dtend if event_by_id[id][:dtend] < dtend
end

locations_by_url.each do |url, info|
  response = HTTParty.get(url)
  if response.code != 200
    raise "Error getting #{url} --> #{response.code}"
  end

  doc = Nokogiri::HTML(response.body)

  locations_by_url[url][:name] = doc.css('h3.large-margin-right').last.text.strip
  locations_by_url[url][:address] = doc.css('.vcard .adr').text.strip.split(/[\t\n]+/).map(&:strip).join(', ')
end


event_by_id.each do |id, event|
  puts "BEGIN:VEVENT"
  puts "UID:LVCSN-#{id}"
  puts "SUMMARY:#{event[:name]}"
  puts "URL:#{event[:url]}"
  puts "LOCATION:#{locations_by_url[event[:location]][:address]}"

  # https://www.kanzaki.com/docs/ical/dtstamp.html - apparently required
  puts "DTSTAMP:#{"%04d%02d%02d" % [event[:dtstart].year, event[:dtstart].month, event[:dtstart].day]}T000000Z"
  puts "DTSTART;VALUE=DATE:#{"%04d%02d%02d" % [event[:dtstart].year, event[:dtstart].month, event[:dtstart].day]}"
  puts "DTEND;VALUE=DATE:#{"%04d%02d%02d" % [event[:dtend].year, event[:dtend].month, event[:dtend].day]}"
  puts "ORGANIZER;CN=LVMS:MAILTO:info@lasvegascarmeets.com"
  # puts "GEO:36.2724;-115.0104"
  puts "END:VEVENT"
end

puts "END:VCALENDAR"
