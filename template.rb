require 'securerandom'

CAPISTRANO_GEM_VERSION = '3.11.0'
RUBY_VERSION           = '2.5.1'
TEMPLATES_PATH         = File.expand_path('../templates', __FILE__)

def template_content(file_path, vars = {})
  content = File.read(File.join(TEMPLATES_PATH, file_path))

  vars == {} ? content : content % vars
end

def parse_args(key)
  params_index = ARGV.index(key)
  return [] if params_index.blank?

  values = ARGV[params_index + 1]
  return [] if values.start_with?('-')

  values&.split(',') || []
end

ruby_version = ARGV.include?('-ruby-version') ? parse_args('-ruby-version') : RUBY_VERSION
skip_theme   = ARGV.include?('--skip-theme')
assets_names = parse_args('-compressed-assets')

create_file 'README.md',      template_content('/README.md'), force: true
create_file 'Gemfile',        template_content('/Gemfile', capistrano_version: CAPISTRANO_GEM_VERSION)
create_file '.gitlab-ci.yml', template_content('/config/.gitlab-ci.yml', app_name: app_name, ruby_version: ruby_version)
create_file '.rubocop.yml',   template_content('/config/.rubocop.yml')
initializer 'errbit.rb',      template_content('/config/initializers/errbit.rb')
application template_content('/config/application.rb.additions')
environment template_content('/config/environments/production.rb.additions', app_name: app_name), env: 'production'
environment template_content('/config/environments/development.rb.additions'), env: 'development'

inside('config') do |config_path|
  inside('environments') do
    prepend_to_file 'production.rb', %q(require 'syslog/logger'
                                        require 'uglifier')
    `cp production.rb staging.rb`
  end

  secret_key_base = SecureRandom.hex(64)

  remove_file 'database.yml'
  remove_file 'credentials.yml.enc'
  remove_file "master.key"


  create_file 'database.yml.example', template_content('/config/database.yml.example', app_name: app_name)
  create_file 'database.yml.ci',      template_content('/config/database.yml.ci', app_name: app_name)
  create_file 'secrets.yml',          template_content('/config/secrets.yml.sample', secret_key_base: secret_key_base)
  create_file 'secrets.yml.sample',   template_content('/config/secrets.yml.sample', secret_key_base: secret_key_base)
  create_file 'secrets.yml.ci',       template_content('/config/secrets.yml.sample', secret_key_base: secret_key_base)

  copy_file "#{config_path}/database.yml.example", "#{config_path}/database.yml"
end

environment template_content('/config/environments/staging.rb.additions', app_name: app_name), env: 'staging'

inside('app/views/layouts') do
  remove_file 'application.html.erb'
  remove_file 'mailer.html.erb'
  remove_file 'mailer.text.erb'

  create_file 'application.html.slim', template_content('/app/views/layouts/application.html.slim', app_name: app_name.upcase)
  create_file 'mailer.html.slim',      template_content('/app/views/layouts/mailer.html.slim')
  create_file 'mailer.text.slim',      template_content('/app/views/layouts/mailer.text.slim')
end


inside('app/assets/javascripts') do
  create_file 'errbit.js.erb', template_content('/app/assets/javascripts/errbit.js.erb')
end

inside('bin') do
  create_file 'cisetup', template_content('/bin/cisetup')
  chmod 'cisetup', 0755
end

run 'bundle install'

unless skip_theme
  inside('app/assets') do
    append_to_file 'javascripts/application.js', %q(
      //= require bootstrap_sb_admin_base_v2
    )
    remove_file 'stylesheets/application.css'
    create_file 'stylesheets/application.css.scss', template_content('/app/assets/stylesheets/application.css.scss')
  end
end

run 'bundle exec cap install'

create_file 'Capfile', template_content('/Capfile'), force: true

append_to_file '.gitignore', %q(.idea/
  config/database.yml
  config/secrets.yml
  dump.rdb
)

inside('config') do
  create_file 'deploy.rb', template_content('/config/deploy.rb',
                                            app_name: app_name,
                                            capistrano_version: CAPISTRANO_GEM_VERSION,
                                            assets_names: assets_names), force: true

  inside('deploy') do
    create_file 'production.rb', template_content('/config/deploy/production.rb', app_name: app_name), force: true
    create_file 'staging.rb',    template_content('/config/deploy/staging.rb', app_name: app_name),    force: true
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

