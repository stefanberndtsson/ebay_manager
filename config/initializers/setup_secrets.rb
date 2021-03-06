token_file = "#{Rails.root}/config/tokens.yml"

if File.exist?(token_file)
  tokens = YAML.load(File.read(token_file))
  if tokens["google"] || tokens["google"]["app"]
    app = tokens["google"]["app"]
    if Rails.application.secrets.google_email.nil? && app["email"]
      Rails.application.secrets.google_email = app["email"]
    end
    if Rails.application.secrets.google_password.nil? && app["password"]
      Rails.application.secrets.google_password = app["password"]
    end
  end
  if Rails.env == "development" && tokens["devel"] && tokens["devel"]["local_data_dir"]
    Rails.application.secrets.local_data_dir = tokens["devel"]["local_data_dir"]
  end
end
