require 'rails_helper'
require 'github_web_hook_request'

RSpec.describe GithubWebHookController, type: :controller do
  let(:github_user) { double(login: 'patronus-io', token: 'abc123') }
  let(:github_repo) { double(name: 'testing', full_name: 'patronus-io/testing') }

  before(:all) do
    # TODO: should only create if it does not exist. there must a better way to do this...
    u = User.create(username: 'patronus-io', github_token: 'abc123')
    r = Repo.create(name: 'patronus-io/testing')
    Reviewership.create(user: u, repo: r)
  end

  before(:each) do
    allow(controller).to receive(:github_user).and_return(github_user)
  end

  def do_not_interact_with_github
    expect(Octokit::Client).not_to receive(:new)
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
      it 'ignores status with an invalid commit message' do
        GithubWebHookRequest::Status.new(
          request: request,
          id: 12345,
          sha: '00000000000000000000',
          username: github_user.login,
          user_id: 13788852,
          repo_full_name: github_repo.full_name,
          context: 'does not matter',
          state: 'Pending',
          commit_params: {
            tree_sha: '11111111111111111111',
            author_is_committer: true,
            author: {
              id: 98429,
              username: 'chalkos',
              name: 'Bruno Ferreira',
            },
            message: 'this message does not match the required format',
          },
          branches: [],
          repository_params: {
            id: 1,
            name: github_repo.name,
          },
        )

        post :create
        expect(response).to have_http_status(202)
      end
    end

    describe 'with issue_comment event' do
      pending 'is handled'
    end

    describe 'with pull_request event' do
      pending 'is handled'
    end
  end

end

