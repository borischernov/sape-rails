require "sape-rails/version"
require "sape-rails/sape"
require "sape-rails/php_serialize"
if defined?(Rails)
  require "sape-rails/helpers"
  require "sape-rails/railtie"
end 
