if Rails.env.staging? || Rails.env.production?
  Airbrake.configure do |config|
    config.project_key = Rails.application.secrets.errbit[:project_key]
    config.project_id = 1
    config.host = 'https://errbit.sumatosoft.com'
  end
end
