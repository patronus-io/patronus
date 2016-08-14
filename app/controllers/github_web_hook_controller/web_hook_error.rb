class GithubWebHookController
  class WebHookError < StandardError
    attr :status
    def initialize(msg=nil, status=500)
      @status = status
      super msg
    end
  end

  class WebHookParametersError < WebHookError
    def initialize(params:{})
      @status = 202
      super "#{params[:msg] || 'Invalid parameters'}. Parameters: #{params.inspect}"
    end
  end
end