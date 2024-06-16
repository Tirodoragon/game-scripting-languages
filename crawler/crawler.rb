require 'nokogiri'
require 'httparty'

HEADERS = {
  "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
  "Accept-Language" => "pl-PL,pl;q=0.9,en;q=0.8,en-US;q=0.7,fa;q=0.6",
  "Accept-Encoding" => "gzip, deflate, br, zstd",
  "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,/;q=0.8,application/signed-exchange;v=b3;q=0.7",
}

def fetch_page(url)
  response = HTTParty.get(url, headers: HEADERS)
  Nokogiri::HTML(response.body)
end

def fetch_search_page(keyword, page_number)
  url = "https://www.amazon.pl/s?k=#{keyword}&page=#{page_number}&__mk_pl_PL=%C3%85M%C3%85%C5%BD%C3%95%C3%91"
  fetch_page(url)
end

def fetch_product_data(page)
  page.css('div.sg-col-4-of-24.sg-col-4-of-12.s-result-item.s-asin.sg-col-4-of-16.sg-col.s-widget-spacing-small.sg-col-4-of-20')
end

def extract_product_info(product)
  return nil if product.css('span.a-size-small').text == "Obecnie niedostępny." || product.css('a.a-button-text').text == "Wyświetl opcje"

  title = product.css('span.a-size-base-plus.a-color-base.a-text-normal').text

  if product.css('span.a-size-base.a-color-secondary').text == "Brak dostępnych proponowanych opcji zakupu"
    unavailable = product.css('div.a-row.a-size-base.a-color-secondary')
    price = unavailable.css('span.a-color-base').text
  else
    whole_price = product.css('span.a-price-whole').text.split(',').first
    fraction_price = product.css('span.a-price-fraction').text[0, 2]
    price = "#{whole_price},#{fraction_price} zł"
  end

  link = "https://www.amazon.pl" + product.css('a.a-link-normal.s-underline-text.s-underline-link-text.s-link-style.a-text-normal').attr('href').value
  { title: title, price: price, link: link }
end

def extract_additional_info(subpage)
  color_info = nil
  item_weight_info = nil
  material_info = nil
  memory_info = nil
  model_year_info = nil
  system_info = nil
  theme_info = nil

  tr = subpage.css('tr.a-spacing-small.po-color')
  unless tr.empty?
    color_attr = tr.css('span.a-size-base.a-text-bold').text
    color_val = tr.css('span.a-size-base.po-break-word').text
    color_info = "#{color_attr}: #{color_val}" unless color_val.empty?
  end

  ul = subpage.css('ul.a-unordered-list.a-vertical.a-spacing-mini')
  unless ul.empty?
    description_items = ul.css('li').map(&:text).map(&:strip)
    description_info = "Opis:\n" + description_items.join("\n")
  end

  tr = subpage.css('tr.a-spacing-small.po-item_weight')
  unless tr.empty?
    item_weight_attr = tr.css('span.a-size-base.a-text-bold').text
    item_weight_val = tr.css('span.a-size-base.po-break-word').text
    item_weight_info = "#{item_weight_attr}: #{item_weight_val}" unless item_weight_val.empty?
  end

  tr = subpage.css('tr.a-spacing-small.po-material')
  unless tr.empty?
    material_attr = tr.css('span.a-size-base.a-text-bold').text
    material_val = tr.css('span.a-size-base.po-break-word').text
    material_info = "#{material_attr}: #{material_val}" unless material_val.empty?
  end

  tr = subpage.css('tr.a-spacing-small.po-memory')
  unless tr.empty?
    memory_attr = tr.css('span.a-size-base.a-text-bold').text
    memory_val = tr.css('span.a-size-base.po-break-word').text
    memory_info = "#{memory_attr}: #{memory_val}" unless memory_val.empty?
  end

  tr = subpage.css('tr.a-spacing-small.po-model_year')
  unless tr.empty?
    model_year_attr = tr.css('span.a-size-base.a-text-bold').text
    model_year_val = tr.css('span.a-size-base.po-break-word').text
    model_year_info = "#{model_year_attr}: #{model_year_val}" unless model_year_val.empty?
  end

  tr = subpage.css('tr.a-spacing-small.po-operating_system')
  unless tr.empty?
    system_attr = tr.css('span.a-size-base.a-text-bold').text
    system_val = tr.css('span.a-size-base.po-break-word').text
    system_info = "#{system_attr}: #{system_val}" unless system_val.empty?
  end

  tr = subpage.css('tr.a-spacing-small.po-theme')
  unless tr.empty?
    theme_attr = tr.css('span.a-size-base.a-text-bold').text
    theme_val = tr.css('span.a-size-base.po-break-word').text
    theme_info = "#{theme_attr}: #{theme_val}" unless theme_val.empty?
  end

  {
    color: color_info,
    description: description_info,
    item_weight: item_weight_info,
    material: material_info,
    memory: memory_info,
    model_year: model_year_info,
    system: system_info,
    theme: theme_info
  }
end

def display_products(products, keyword)
  capitalized_keyword = keyword.split.map.with_index { |word, index| index == 0 ? word.capitalize : word }.join(' ')
  products.each_with_index do |product, index|
    info = extract_product_info(product)
    next if info.nil?
    subpage = fetch_page(info[:link])
    additional_info = extract_additional_info(subpage)
    puts "Produkt: #{info[:title]}"
    puts "Cena: #{info[:price]}"
    
    if additional_info[:system]
      puts additional_info[:system] unless additional_info[:system].to_s.strip.empty?
    end
    
    if additional_info[:memory]
      puts additional_info[:memory] unless additional_info[:memory].to_s.strip.empty?
    end
    
    if additional_info[:color]
      puts additional_info[:color] unless additional_info[:color].to_s.strip.empty?
    end
    
    if additional_info[:model_year]
      puts additional_info[:model_year] unless additional_info[:model_year].to_s.strip.empty?
    end
    
    if additional_info[:item_weight]
      puts additional_info[:item_weight] unless additional_info[:item_weight].to_s.strip.empty?
    end
    
    if additional_info[:theme]
      puts additional_info[:theme] unless additional_info[:theme].to_s.strip.empty?
    end
    
    if additional_info[:material]
      puts additional_info[:material] unless additional_info[:material].to_s.strip.empty?
    end

    if additional_info[:description]
      puts additional_info[:description] unless additional_info[:description].to_s.strip.empty?
    end
    
    puts "\n\n" unless index == products.size - 1
  end
end

if ARGV.empty?
  puts "Usage: ruby script_name.rb <keyword1> <keyword2> ... <keywordN>"
  exit
end

keyword = ARGV.join(' ')
all_products = []

(1..3).each do |page_number|
  page = fetch_search_page(keyword, page_number)
  products = fetch_product_data(page)
  all_products.concat(products)
end

display_products(all_products, keyword)