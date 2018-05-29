CAPISTRANO_GEM_VERSION = '3.8.2'

def parse_args(key)
  params_index = ARGV.index(key)
  return [] if params_index.blank?

  values = ARGV[params_index + 1]
  return [] if values.start_with?('-')

  values&.split(',') || []
end

skip_theme = ARGV.include?('--skip-theme')
assets_names = parse_args('-compressed-assets')

create_file 'Gemfile', <<RUBY
source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "\#{repo_name}/\#{repo_name}" unless repo_name.include?("/")
  "https://github.com/\#{repo_name}.git"
end

gem 'rails', '~> 5.2.0'
gem 'pg', '~> 0.21.0'
gem 'puma', '~> 3.9'
gem 'sass-rails', '~> 5.0.6'
gem 'uglifier', '~> 3.2'

gem 'jquery-rails', '~> 4.3.1'
gem 'bootstrap-sass', '~> 3.3.7'

gem 'slim', '~> 3.0.8'
gem 'slim-rails', '~> 3.1.2'

gem 'simple_form', '~> 4.0.1'
#{skip_theme ? '' : "gem 'bootstrap_sb_admin_base_v2', '~> 0.3.3'"}

# Authentication && Authorization
gem 'devise', '~> 4.4.0'

#gem 'omniauth-oauth2', '~> 1.4.0'
#gem 'omniauth-facebook', '~> 4.0.0'
#gem 'omniauth-linkedin', '~> 0.2.0'
#gem 'omniauth-twitter', '~> 1.3.0'
#gem 'omniauth-google-oauth2', '~> 0.5.0'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false


source 'https://rails-assets.org' do
  gem 'rails-assets-airbrake-js-client', '~> 0.9'
end

group :staging, :production do
  gem 'airbrake', '~> 6.2.0'
end

group :staging, :development do
  gem 'safety_mailer', '~> 0.0.10'
end

group :development do
  gem 'capistrano', '~> #{CAPISTRANO_GEM_VERSION}'
  gem 'capistrano-rails', '~> 1.3.0', require: false
  gem 'capistrano-bundler', '~> 1.2.0', require: false
  gem 'capistrano-passenger', '~> 0.2.0', require: false
  gem 'capistrano-rvm', '~> 0.1.2', require: false
  gem 'capistrano-the-best-compression', git: 'git@github.com:SumatoSoft/capistrano-the-best-compression.git'
  gem 'annotate', '~> 2.7.2'
  gem 'listen', '~> 3.1.5'
  gem 'letter_opener', '~> 1.4.1'
  gem 'rubocop', '~> 0.49', require: false
end

group :development, :test do
  gem 'pry', '~> 0.10.4'
end

group :test do
  gem 'factory_girl_rails', '~> 4.8'
  gem 'pronto'
  gem 'pronto-rubocop', require: false
  gem 'pronto-flay', require: false
end
RUBY

application %q(config.generators do |g|
      g.orm             :active_record
      g.template_engine :slim
      g.assets     false
      g.helper     false
    end
)

initializer 'errbit.rb', <<RUBY
if Rails.env.staging? || Rails.env.production?
  Airbrake.configure do |config|
    config.project_key = Rails.application.secrets.errbit[:project_key]
    config.project_id = 1
    config.host = 'https://errbit.sumatosoft.com'
  end
end
RUBY

environment %Q(config.assets.configure do |env|
    env.gzip = false
  end
  config.assets.js_compressor = Uglifier.new output: { comments: :none }
            ), env: 'production'

environment %q(config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }

  config.action_mailer.delivery_method = :safety_mailer
  config.action_mailer.safety_mailer_settings = {
    allowed_matchers: [ // ],
    delivery_method: :letter_opener,
    delivery_method_settings: {
      location: '/tmp'
    }
  }
), env: 'development'

inside('config') do |config_path|

#   append_to_file 'secrets.yml', <<YAML
# errbit:
#   project_key: 'CHANGE_ME'
#
# staging:
#   secret_key_base: <%= ENV["SECRET_KEY_BASE"] %>
#   mailer:
#     user_name: 'CHANGE_ME'
#     password: 'CHANGE_ME'
#     domain: '#{app_name}.demo.sumatosoft.com'
#     address: 'CHANGE_ME'
#   errbit:
#     project_key: 'CHANGE_ME'
# YAML

#  copy_file "#{config_path}/secrets.yml", "#{config_path}/secrets.yml.example"

  inside('environments') do
    prepend_to_file 'production.rb', %q(require 'syslog/logger'
require 'uglifier'

)
    `cp production.rb staging.rb`
  end

  remove_file 'database.yml'

  create_file 'database.yml.example', <<YAML
default: &default
  adapter: postgresql
  encoding: unicode
  username: postgres
  pool: 5

development:
  <<: *default
  database: #{app_name}_dev

test:
  <<: *default
  database: #{app_name}_test

production:
  <<: *default
  database: #{app_name}_prod
  username: username
  password: password

staging:
  <<: *default
  database: #{app_name}_staging
YAML

  create_file 'database.yml.circle_ci', <<YAML
default: &default
  adapter: postgresql
  encoding: unicode
  # For details on connection pooling, see Rails configuration guide
  # http://guides.rubyonrails.org/configuring.html#database-pooling
  host: localhost
  user: root

test:
  <<: *default
  database: #{app_name}_test

YAML

  copy_file "#{config_path}/database.yml.example", "#{config_path}/database.yml"
end

environment %Q(config.logger = Syslog::Logger.new '#{app_name}_production'
            ), env: 'production'

environment %Q(config.logger = Syslog::Logger.new '#{app_name}_staging'

  config.action_mailer.delivery_method = :safety_mailer
  config.action_mailer.safety_mailer_settings = {
    allowed_matchers: [ // ],
    delivery_method: :smtp,
    delivery_method_settings: {
      user_name: Rails.application.secrets.mailer[:user_name],
      password: Rails.application.secrets.mailer[:password],
      domain: Rails.application.secrets.mailer[:domain],
      address: Rails.application.secrets.mailer[:address],
      port: 587,
      authentication: :plain,
      enable_starttls_auto: true
    }
  }

  config.action_mailer.default_url_options = { host: '#{app_name}.demo.sumatosoft.com' }
), env: 'staging'

inside('app/views/layouts') do
  remove_file 'application.html.erb'
  remove_file 'mailer.html.erb'
  remove_file 'mailer.text.erb'

  create_file 'application.html.slim', <<SLIM
doctype html
html
  head
    title
      | #{app_name.upcase}
    = csrf_meta_tags
    = stylesheet_link_tag    'application', media: 'all'
    = javascript_include_tag 'application'
    = yield
SLIM

  create_file 'mailer.html.slim', <<SLIM
doctype html
html
  head
    meta[http-equiv="Content-Type" content="text/html; charset=utf-8"]
    style
      |  /* Email styles need to be inline */
  body
    = yield
SLIM

  create_file 'mailer.text.slim', '= yield'
end

inside('app/assets/javascripts') do
  create_file 'errbit.js.erb', %q(//= require airbrake-js-client
<% if Rails.env.staging? || Rails.env.production?%>
var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
$(document).ready(function() {
  var airbrake, url;
  airbrake = new airbrakeJs.Client({
    projectId: "1",
    projectKey: "<%= Rails.application.secrets.errbit[:project_key] %>"
  });
  url = 'https://errbit.sumatosoft.com';
  airbrake.setHost(url);
  airbrake.addFilter(function(notice) {
    notice.context.environment = '<%= Rails.env %>';
    return notice;
  });
  return window.onerror = __bind(function(message, file, line, column, errorObj) {
    var data;
    data = {
      error: {
        message: message,
        fileName: file,
        lineNumber: line,
        column: column
      }
    };
    if (errorObj != null) {
      data['error'] = $.extend(data['error'], {
        stack: errorObj.stack
      });
    }
    return airbrake.notify(data);
  }, this);
});
<% end %>
)
end

inside('bin') do
  create_file 'cisetup', <<BASH
export PULL_REQUEST_URL=${CI_PULL_REQUEST}
echo ${CI_PULL_REQUEST}
export PRONTO_PULL_REQUEST_ID=`echo $PULL_REQUEST_URL | grep -o -E '[0-9]+$' | head -1 | sed -e 's/^0\+//'`
(bin/bundle exec pronto run -f github_pr -c origin/master) || true
BASH

  chmod 'cisetup', 0755
end

inside do
  create_file '.rubocop.yml', <<YAML
AllCops:
  Exclude:
    - 'db/**/*'
    - 'bin/**/*'
    - 'Gemfile'
    - 'test/**/*'
  TargetRubyVersion: 2.4

Documentation:
  Enabled: false

DotPosition:
  EnforcedStyle: trailing

Style/FrozenStringLiteralComment:
  Enabled: false

Metrics/LineLength:
  Max: 120

Metrics/AbcSize:
  Max: 30

Metrics/MethodLength:
  Max: 25

Lint/EndAlignment:
  AlignWith: variable

YAML
end

inside do
  create_file 'circle.yml', <<YAML
version: 2
jobs:
  build:
    working_directory: ~/#{app_name}
    docker:
      - image: circleci/ruby:2.4.1-node
        environment:
          RAILS_ENV: test
      - image: circleci/postgres:9.6.3-alpine
        environment:
          POSTGRES_USER: root
          POSTGRES_DB: ggswp_test
      - image: redis:3.2.9-alpine
    steps:
      - run: sudo apt-get install cmake

      - checkout

      # Restore bundle cache
      - type: cache-restore
        key: rails-#{app_name}-{{ checksum "Gemfile.lock" }}

      # Bundle install dependencies
      - run: bundle install --path vendor/bundle

      # Store bundle cache
      - type: cache-save
        key: rails-#{app_name}-{{ checksum "Gemfile.lock" }}
        paths:
          - vendor/bundle
      - run: cp config/database.yml.circle_ci config/database.yml
      - run: cp config/secrets.yml.example config/secrets.yml

      - run: bin/cisetup

      # Database setup
      - run: bundle exec rake db:create db:schema:load

      # Run rspec in parallel
      - type: shell
        command: |
          bundle exec rake
      # Save artifacts
      - type: store_test_results
        path: /tmp/
YAML
end

run 'bundle install'

unless skip_theme
  inside('app/assets') do
    append_to_file 'javascripts/application.js', %q(
//= require bootstrap_sb_admin_base_v2
  )
    remove_file 'stylesheets/application.css'
    create_file 'stylesheets/application.css.scss', %q(
@import 'font-awesome';
@import 'bootstrap_sb_admin_base_v2';
  )
  end
end

run 'bundle exec cap install'

remove_file 'Capfile'
create_file 'Capfile', %q(
require "capistrano/setup"
require "capistrano/deploy"

require 'capistrano/rvm'
# require 'capistrano/rbenv'
# require 'capistrano/chruby'
require 'capistrano/bundler'
require 'capistrano/rails/assets'
require 'capistrano/rails/migrations'
require 'capistrano/passenger'

Dir.glob("lib/capistrano/tasks/*.rake").each { |r| import r }

spec = Gem::Specification.find_by_name 'capistrano-the-best-compression'
load "#{spec.gem_dir}/lib/tasks/compress.rake"
)

append_to_file '.gitignore', %q(.idea/
config/database.yml
config/secrets.yml
)

inside('config') do
  remove_file 'deploy.rb'
  create_file 'deploy.rb', %Q(lock '#{CAPISTRANO_GEM_VERSION}'
set :application, '#{app_name}'
set :repo_url, 'git@github.com:SumatoSoft/#{app_name}.git'

after 'deploy:normalize_assets', '_compress_assets' do
  Rake::Task['deploy:compress_assets'].invoke(#{assets_names})
end
after 'deploy:normalize_assets', 'deploy:compress_png'
  )

  inside('deploy') do
    remove_file 'production.rb'
    create_file 'production.rb', %Q(set :deploy_to,             '/var/www/apps/#{app_name}_production'
set :rails_env,             'production'
set :branch,                ENV['BRANCH'] || 'master'

server 'server_ip', user: 'app', roles: %w{app db web}
set :linked_files, %w(config/database.yml config/secrets.yml)
  )

    remove_file 'staging.rb'
    create_file 'staging.rb', %Q(set :deploy_to,             '/var/www/apps/#{app_name}_staging'
set :rails_env,             'staging'
set :branch,                ENV['BRANCH'] || 'develop'

server 'server_ip', user: 'app', roles: %w{app db web}
set :linked_files, %w(config/database.yml config/secrets.yml)
  )
  end
end

run 'rails generate simple_form:install'
run 'rails generate devise:install'
run 'rails generate devise User'

devise_initializer_path = "config/initializers/devise.rb"
inject_into_file(devise_initializer_path, :after => "  # ==> OmniAuth") do
  <<-CONTENT
  # config.omniauth :facebook, Rails.application.secrets.facebook[:client_id], Rails.application.secrets.facebook[:secret_key],
  #                 scope: 'public_profile,email',
  #                 info_fields: 'email,first_name,last_name,verified'
  # config.omniauth :linkedin, Rails.application.secrets.linkedin[:client_id], Rails.application.secrets.linkedin[:secret_key]
  # config.omniauth :google_oauth2, Rails.application.secrets.google[:client_id], Rails.application.secrets.google[:secret_key],
  #                 scope: 'profile,email'

  CONTENT
end

