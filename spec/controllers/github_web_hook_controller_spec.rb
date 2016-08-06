require 'rails_helper'
require 'github_web_hook_request'

RSpec.describe GithubWebHookController, type: :controller do
  let(:github_user) { double(login: 'alice', token: 'abc123') }

  before(:each) do
    allow(controller).to receive(:github_user).and_return(github_user)
  end

  def build_hook(event, params = {})
    @hook = GithubWebHookRequest.new(event, params, @request)
  end

  context 'POST #create' do
    describe 'with an unrecognised event' do
      it 'returns http 501' do
        build_hook 'invalid-event'
        post :create
        expect(response).to have_http_status(501)
      end
    end

    describe 'with ping event' do
      it 'returns http 200' do
        build_hook 'ping'
        post :create
        expect(response).to have_http_status(200)
      end

      it 'returns http 401 on signature mismatch' do
        build_hook 'ping'
        request.headers['X-Hub-Signature'] = 'invalid signature'
        post :create, @hook.body
        expect(response).to have_http_status(401)
      end
    end

    describe 'with status event' do

    end
  end

end

