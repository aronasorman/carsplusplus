require 'mechanize'
require 'sqlite3'
class Scraper
  def initialize
    @agent = Mechanize.new
    @db = SQLite3::Database.new "cars.db"
    @db.execute "CREATE TABLE IF NOT EXISTS cars (id INTEGER PRIMARY KEY, model TEXT, category TEXT, seat_number INTEGER, year INTEGER)"
    @db.execute "CREATE TABLE IF NOT EXISTS brands (id INTEGER PRIMARY KEY, name TEXT)"
    true
  end

  def parse_car_index_page(url)
    #assumes that the url given is the first page
    page = @agent.get(url)
    pages = page.links_with(:text => /\d+/, :href => /\?page=\d+/).map(&:click) << page
    puts pages
    pages.each do |p|
      begin
        parse_car_list_page p
      rescue Exception
        next
      end
    end
    "done"
  end

  def parse_car_list_page(page)
    case page
    when String
      page = @agent.get page
    end

    spec_links = page.links_with(:href => /specs(20|199|198)\d+/)
    spec_links.each { |link| write_to_db parse_car_spec_page link.click }
  end

  def parse_car_spec_page(page)
    case page
    when String
      page = @agent.get page
    end

    model_label_node = page.search('td').find {|td| td.text == 'Model:'}
    model = model_label_node.next.text unless model_label_node.nil? # i know it's impossible, but just to make sure

    category_label_node = page.search('td').find { |td| td.text == 'Category:' }
    category = category_label_node.next.text unless category_label_node.nil?

    seat_number_label_node = page.search('td').find {|td| td.text == 'Seats:' }
    seat_number = seat_number_label_node.next.text unless seat_number_label_node.nil?

    year_label_node = page.search('td').find {|td| td.text == 'Year:'}
    year = year_label_node.next.text unless year_label_node.nil?

    {category: category, seat_number: seat_number, model: model, year: year}
  end

  def write_to_db(car_info)
    puts "writing #{car_info[:model]} into DB"
    stmt = @db.prepare %q{INSERT INTO cars (model, category, seat_number, year) VALUES (?, ?, ?, ?)}
    stmt.bind_params car_info[:model], car_info[:category], car_info[:seat_number], car_info[:year]
    stmt.execute
  end

  def get_brand(url)
    url.split('/').last.split('cars.php').first.gsub('_', ' ').strip.capitalize
  end

  def write_brand_to_db(brand)
    stmt = @db.prepare %q{INSERT INTO brands (name) VALUES (?)}
    stmt.bind_params brand
    stmt.execute
  end
end

if ARGV[0].nil?
  puts 'please give a text file of urls as argument'
  exit 1
end
file = File.new(ARGV[0], 'r')
scraper = Scraper.new
while (url = file.gets)
  puts "getting list of cars from #{url}"
  scraper.write_brand_to_db scraper.get_brand url
  scraper.parse_car_index_page(url)
end
