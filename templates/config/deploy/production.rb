set :deploy_to,             '/var/www/apps/%{app_name}_production'
set :rails_env,             'production'
set :branch,                ENV['BRANCH'] || 'master'

server 'server_ip', user: 'app', roles: [:app, :db, :web]
set :linked_files, ['config/database.yml', 'config/secrets.yml']
