require 'nokogiri'
require 'httparty'

def fetch_page(url)
  options = {
    headers: {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
      "Accept-Language" => "pl-PL,pl;q=0.9,en;q=0.8,en-US;q=0.7,fa;q=0.6",
      "Accept-Encoding" => "gzip, deflate, br, zstd",
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
    }
  }
  response = HTTParty.get(url, options)
  Nokogiri::HTML(response.body)
end

def fetch_product_data(page)
  page.css('div.sg-col-4-of-24.sg-col-4-of-12.s-result-item.s-asin.sg-col-4-of-16.sg-col.s-widget-spacing-small.sg-col-4-of-20')
end

def extract_product_info(product)
  title = product.css('span.a-size-base-plus.a-color-base.a-text-normal').text

  if product.css('span.a-size-base.a-color-secondary').text == "Brak dostępnych proponowanych opcji zakupu"
    unavailable = product.css('div.a-row.a-size-base.a-color-secondary')
    price = unavailable.css('span.a-color-base').text
  else
    whole_price = product.css('span.a-price-whole').text
    fraction_price = product.css('span.a-price-fraction').text
    price = "#{whole_price}#{fraction_price} zł"
  end

  { title: title, price: price }
end

def display_products(products)
  products.each_with_index do |product, index|
    info = extract_product_info(product)
    puts "Telefon: #{info[:title]}"
    puts "Cena: #{info[:price]}"
    puts "\n\n" unless index == products.size - 1
  end
end

url = 'https://www.amazon.pl/s?i=electronics&rh=n%3A20657432031%2Cn%3A20788252031%2Cn%3A20788267031%2Cn%3A26955202031&dc&fs=true&ds=v1%3A%2FbFoBvIpf7HI5KI4UWVDHVfRENR8PNdMH11uZx%2FqHVk&qid=1718560403&rnid=20657432031&ref=sr_nr_n_1'

page = fetch_page(url)
products = fetch_product_data(page)
display_products(products)