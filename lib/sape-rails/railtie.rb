module Sape
  class Railtie < ::Rails::Railtie #:nodoc:
  
    initializer 'sape' do |_app|
      Sape::Railtie.load_config
      ActionView::Base.send :include, Sape::Helpers
    end

    def load_config
      @config = YAML.load_file(Rails.root.join('config/sape.yml')).symbolize_keys
      @config[:filename] ||= Rails.root.join('tmp/links.db')
    end
    
  end
end
