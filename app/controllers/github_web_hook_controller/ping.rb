class GithubWebHookController
  class Ping < Event
    def run!
      Rails.logger.info { '-> Ping!' }
    end

    private

    def init_msg
      Rails.logger.info { 'Github hook handler: ping' }
    end
  end
end