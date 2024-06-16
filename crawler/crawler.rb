require 'nokogiri'
require 'httparty'

def fetch_page(keyword, page_number)
  url = "https://www.amazon.pl/s?k=#{keyword}&page=#{page_number}&__mk_pl_PL=%C3%85M%C3%85%C5%BD%C3%95%C3%91"
  options = {
    headers: {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
      "Accept-Language" => "pl-PL,pl;q=0.9,en;q=0.8,en-US;q=0.7,fa;q=0.6",
      "Accept-Encoding" => "gzip, deflate, br, zstd",
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,/;q=0.8,application/signed-exchange;v=b3;q=0.7",
    }
  }
  response = HTTParty.get(url, options)
  Nokogiri::HTML(response.body)
end

def fetch_product_data(page)
  page.css('div.sg-col-4-of-24.sg-col-4-of-12.s-result-item.s-asin.sg-col-4-of-16.sg-col.s-widget-spacing-small.sg-col-4-of-20')
end

def extract_product_info(product)
  if (product.css('span.a-size-small').text == "Obecnie niedostępny.") || (product.css('a.a-button-text').text == "Wyświetl opcje")
    return nil
  end
  title = product.css('span.a-size-base-plus.a-color-base.a-text-normal').text

  if product.css('span.a-size-base.a-color-secondary').text == "Brak dostępnych proponowanych opcji zakupu"
    unavailable = product.css('div.a-row.a-size-base.a-color-secondary')
    price = unavailable.css('span.a-color-base').text
  else
    whole_price = product.css('span.a-price-whole').text.split(',').first
    fraction_price = product.css('span.a-price-fraction').text[0, 2]
    price = "#{whole_price},#{fraction_price} zł"
  end

  { title: title, price: price }
end

def display_products(products, keyword)
  capitalized_keyword = keyword.split.map.with_index { |word, index| index == 0 ? word.capitalize : word }.join(' ')
  products.each_with_index do |product, index|
    info = extract_product_info(product)
    next if info.nil?
    puts "#{capitalized_keyword}: #{info[:title]}"
    puts "Cena: #{info[:price]}"
    puts "\n\n" unless index == products.size - 1
  end
end

if ARGV.empty?
  puts "Usage: ruby script_name.rb <keyword1> <keyword2> ... <keywordN>"
  exit
end

keyword = ARGV.join(' ')
all_products = []

(1..4).each do |page_number|
  page = fetch_page(keyword, page_number)
  products = fetch_product_data(page)
  all_products.concat(products)
end

display_products(all_products, keyword)