set :deploy_to,             '/var/www/apps/%{app_name}_staging'
set :rails_env,             'staging'
set :branch,                ENV['BRANCH'] || 'develop'

server 'server_ip', user: 'app', roles: [:app, :db, :web]
set :linked_files, ['config/database.yml', 'config/secrets.yml']
