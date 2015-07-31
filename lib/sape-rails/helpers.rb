module Sape
  module Helpers
    def return_sape_links(num = nil, opts = {})
      Sape::Processor.new(Sape::Railtie.config[:user_id], request, Sape::Railtie.config).return_links(num, opts).html_safe
    end

    def return_sape_block_links(num = nil, opts = {})
      Sape::Processor.new(Sape::Railtie.config[:user_id], request, Sape::Railtie.config).return_block_links(num, opts).html_safe
    end

    def return_sape_counter
      Sape::Processor.new(Sape::Railtie.config[:user_id], request, Sape::Railtie.config).return_counter.html_safe
    end
  end
end

