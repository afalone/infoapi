source 'https://rubygems.org'

gem 'sentimeta', "~> 0.0.2"

gem "bundler", "~> 1.6"
gem "rake", "~> 10.0"
gem "sinatra"
gem "sinatra-contrib"
gem "thin"
gem "sequel"
gem "pg"
gem "json"

group :development do
  gem "capistrano"
  gem "capistrano-rvm"
  gem "capistrano-bundler"
  gem "capistrano-thin"
end
group *%i(development test) do
  gem "rspec"
end

group :test do
  gem 'fakeweb', require: 'fakeweb/safe'
  gem 'simplecov', require: false
end
