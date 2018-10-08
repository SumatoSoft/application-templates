lock '%{capistrano_version}'
set :application, '%{app_name}'
set :repo_url, 'git@github.com:SumatoSoft/%{app_name}.git'

after 'deploy:normalize_assets', '_compress_assets' do
  Rake::Task['deploy:compress_assets'].invoke(%{assets_names})
end
after 'deploy:normalize_assets', 'deploy:compress_png'
