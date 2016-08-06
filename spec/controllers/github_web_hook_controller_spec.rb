require 'rails_helper'
require 'github_web_hook_request'

RSpec.describe GithubWebHookController, type: :controller do
  let(:github_user) { double(login: 'alice', token: 'abc123') }

  before(:each) do
    allow(controller).to receive(:github_user).and_return(github_user)
  end

  context 'POST #create' do
    describe 'with an unrecognised event' do
      it 'returns http 501' do
        GithubWebHookRequest.new('invalid-event', request)
        post :create
        expect(response).to have_http_status(501)
      end
    end

    describe 'with ping event' do
      it 'returns http 200' do
        GithubWebHookRequest::Ping.new(request: request)
        post :create
        expect(response).to have_http_status(200)
      end

      it 'returns http 401 on signature mismatch' do
        GithubWebHookRequest::Ping.new(request: request)
        request.headers['X-Hub-Signature'] = 'invalid signature'
        post :create
        expect(response).to have_http_status(401)
      end
    end

    describe 'with status event' do
      pending 'is handled'
    end

    describe 'with issue_comment event' do
      pending 'is handled'
    end

    describe 'with pull_request event' do
      pending 'is handled'
    end
  end

end

