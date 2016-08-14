class GithubWebHookController
  class Event
    attr :payload, :app_client, :bot_client

    def initialize(payload, app_client, bot_client)
      @payload = payload
      @app_client = app_client
      @bot_client = bot_client
      init_msg
    end

    def run!
      # to override
    end

    private

    def init_msg
      # do nothing, for subclasses do Rails.logger.info { 'Github hook handler: event_name' }
    end
  end
end