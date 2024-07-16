require 'nokogiri'
require 'rest-client'
require 'csv'

class CompaniesController < ApplicationController
  def scrape
    n = params[:n].to_i
    n = 10 if n <= 0  # Default to 10 if 'n' is not provided or invalid
    
    filters = params.permit(:batch, :industry, :region, :tag, :company_size, :top_companies, :is_hiring, :nonprofit, :black_founded, :hispanic_latino_founded, :women_founded)

    companies = scrape_companies(n, filters)

    # Generate CSV data
    csv_data = generate_csv(companies)

    send_data csv_data, filename: "yc_companies.csv"
  end

  private

  def scrape_companies(n, filters)
    url = "https://www.ycdb.co/"
    page_num = 1
    companies = []

    loop do
      break if companies.size >= n

      response = RestClient.get(url, params: { page: page_num })
      doc = Nokogiri::HTML(response.body)

      doc.css('.company').each do |company|
        break if companies.size >= n

        company_name = company.css('.name').text.strip
        company_location = company.css('.location').text.strip
        short_description = company.css('.description').text.strip
        yc_batch = company.css('.batch').text.strip

        # Skip companies based on filters
        next if filter_company?(company_name, filters)

        # Scrape second page details
        details = scrape_second_page(company_name)

        companies << {
          name: company_name,
          location: company_location,
          description: short_description,
          yc_batch: yc_batch,
          website: details[:website],
          founders: details[:founders]
        }
      end

      page_num += 1
    end

    companies.first(n)
  end

  def scrape_second_page(company_name)
    formatted_company_name = company_name.downcase.gsub(' ', '-')
    url = "https://www.ycdb.co/companies/#{formatted_company_name}"
    response = RestClient.get(url)
    doc = Nokogiri::HTML(response.body)

    website = doc.css('.website a').first['href'] if doc.css('.website').first

    founders = []
    doc.css('.founders .person').each do |founder|
      founder_name = founder.css('.name').text.strip
      linkedin_url = founder.css('a.linkedin').first['href'] if founder.css('a.linkedin').first

      founders << {
        name: founder_name,
        linkedin: linkedin_url
      }
    end

    {
      website: website,
      founders: founders
    }
  end

  def filter_company?(company_name, filters)
    # Implement your logic to apply filters here
    # Example: return true if company should be skipped based on filters
    false  # Replace with actual filter logic
  end

  def generate_csv(companies)
    CSV.generate(headers: true) do |csv|
      csv << ['Company Name', 'Location', 'Description', 'YC Batch', 'Website', 'Founder Names', 'LinkedIn URLs']

      companies.each do |company|
        founder_names = company[:founders].map { |founder| founder[:name] }.join(', ')
        linkedin_urls = company[:founders].map { |founder| founder[:linkedin] }.compact.join(', ')

        csv << [
          company[:name],
          company[:location],
          company[:description],
          company[:yc_batch],
          company[:website],
          founder_names,
          linkedin_urls
        ]
      end
    end
  end
end
