namespace :api_keys do
  desc "Generate an API key for a firm and print the token once: bin/rails 'api_keys:generate[FIRM_UUID]'"
  task :generate, [ :firm_uuid ] => :environment do |_task, args|
    firm = Firm.find_by!(uuid: args.fetch(:firm_uuid))
    token = ApiToken.generate
    ApiKeyRepository.create!(firm:, token_digest: ApiToken.digest(token))
    puts token
  end
end
