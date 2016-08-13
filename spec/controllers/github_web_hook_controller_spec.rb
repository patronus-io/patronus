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

  # mocks find_user_reviewership to avoid using the database
  def mock_reviewership(login:, token:, repo_full_name:)
    allow(controller).to receive(:find_user_reviewership) do |repo, sender|
      expect(repo_full_name).to eq(repo)
      expect(login).to eq(sender)
      u = User.new(username: login, github_token: token)
      r = Repo.new(name: repo_full_name)
      Reviewership.new(user: u, repo: r)
    end
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
      let(:user_alice) { double(username: 'alice', user_id: 1, name: 'Alice Allen', email: 'alice@example.com', token: 'alice123') }
      let(:user_bob) { double(username: 'bob', user_id: 2, name: 'Bob Burton', email: 'bob@example.com', token: 'bob456') }

      let(:repo_main) { double(full_name: 'alice/main', name: 'main', id: 1) }

      let(:sha0) { '00000000000000000000' }
      let(:sha1) { '11111111111111111111' }

      let(:default_options) do
        {
          id: 1,
          sha: sha0,
          username: user_alice.username,
          user_id: user_alice.user_id,
          repo_full_name: repo_main.full_name,
          context: 'undefined',
          state: 'Pending',
          commit_params: {
            tree_sha: sha1,
            author_is_committer: true,
            author: {
              id: user_alice.user_id,
              username: user_alice.username,
              name: user_alice.name,
              email: user_alice.email,
            },
            # message: purposely left undefined
          },
          branches: [],
          repository_params: {
            id: repo_main.id,
            name: repo_main.name,
          },
        }
      end

      it 'ignores status with invalid commit message' do
        default_options[:commit_params][:message] = 'this message does not match the pattern'
        mock_reviewership(login: user_alice.username, token: user_alice.token, repo_full_name: repo_main.full_name)

        GithubWebHookRequest::Status.new(**default_options, request: request)
        post :create

        expect(response).to have_http_status(202)
      end

      pending 'when the combined status is pending nothing happens' do
        mock_reviewership(login: 'chalkos', token: 'chalkos_token', repo_full_name: 'chalkos/patronus-testing')
        GithubWebHookRequest::Status.new(request, json_1)

        # TODO: make sure only specific requests are called
        VCR.use_cassette('status_event') do
          post :create
        end
      end

      pending 'when the combined status is success patronus status becomes success'

      pending 'when the combined status is failure patronus status becomes failure'

      pending ''
    end

    describe 'with issue_comment event' do
      pending 'is handled'
    end

    describe 'with pull_request event' do
      pending 'is handled'
    end
  end

  # TODO: remove this after recording the VCR cassettes
  def json_1
    return <<-eos
{
  "id": 660104187,
  "sha": "40d1e58d69628950ed865a2ca5a49bcede85e990",
  "name": "chalkos/patronus-testing",
  "target_url": "https://travis-ci.org/chalkos/patronus-testing/builds/146114767",
  "context": "continuous-integration/travis-ci/push",
  "description": "The Travis CI build failed",
  "state": "failure",
  "commit": {
    "sha": "40d1e58d69628950ed865a2ca5a49bcede85e990",
    "commit": {
      "author": {
        "name": "The Bundler Bot",
        "email": "bundlerbot@users.noreply.github.com",
        "date": "2016-07-20T13:58:05Z"
      },
      "committer": {
        "name": "GitHub",
        "email": "noreply@github.com",
        "date": "2016-07-20T13:58:05Z"
      },
      "message": "Auto merge of PR #12 by patronus from 59bdd46316150a12835af8bb5abe87249b63cc5f onto chalkos:master\\nchalkos => test",
      "tree": {
        "sha": "4e8542ca0d822605c8c4ce782274a87a72ba04e7",
        "url": "https://api.github.com/repos/chalkos/patronus-testing/git/trees/4e8542ca0d822605c8c4ce782274a87a72ba04e7"
      },
      "url": "https://api.github.com/repos/chalkos/patronus-testing/git/commits/40d1e58d69628950ed865a2ca5a49bcede85e990",
      "comment_count": 0
    },
    "url": "https://api.github.com/repos/chalkos/patronus-testing/commits/40d1e58d69628950ed865a2ca5a49bcede85e990",
    "html_url": "https://github.com/chalkos/patronus-testing/commit/40d1e58d69628950ed865a2ca5a49bcede85e990",
    "comments_url": "https://api.github.com/repos/chalkos/patronus-testing/commits/40d1e58d69628950ed865a2ca5a49bcede85e990/comments",
    "author": {
      "login": "bundlerbot",
      "id": 13614622,
      "avatar_url": "https://avatars.githubusercontent.com/u/13614622?v=3",
      "gravatar_id": "",
      "url": "https://api.github.com/users/bundlerbot",
      "html_url": "https://github.com/bundlerbot",
      "followers_url": "https://api.github.com/users/bundlerbot/followers",
      "following_url": "https://api.github.com/users/bundlerbot/following{/other_user}",
      "gists_url": "https://api.github.com/users/bundlerbot/gists{/gist_id}",
      "starred_url": "https://api.github.com/users/bundlerbot/starred{/owner}{/repo}",
      "subscriptions_url": "https://api.github.com/users/bundlerbot/subscriptions",
      "organizations_url": "https://api.github.com/users/bundlerbot/orgs",
      "repos_url": "https://api.github.com/users/bundlerbot/repos",
      "events_url": "https://api.github.com/users/bundlerbot/events{/privacy}",
      "received_events_url": "https://api.github.com/users/bundlerbot/received_events",
      "type": "User",
      "site_admin": false
    },
    "committer": {
      "login": "web-flow",
      "id": 19864447,
      "avatar_url": "https://avatars.githubusercontent.com/u/19864447?v=3",
      "gravatar_id": "",
      "url": "https://api.github.com/users/web-flow",
      "html_url": "https://github.com/web-flow",
      "followers_url": "https://api.github.com/users/web-flow/followers",
      "following_url": "https://api.github.com/users/web-flow/following{/other_user}",
      "gists_url": "https://api.github.com/users/web-flow/gists{/gist_id}",
      "starred_url": "https://api.github.com/users/web-flow/starred{/owner}{/repo}",
      "subscriptions_url": "https://api.github.com/users/web-flow/subscriptions",
      "organizations_url": "https://api.github.com/users/web-flow/orgs",
      "repos_url": "https://api.github.com/users/web-flow/repos",
      "events_url": "https://api.github.com/users/web-flow/events{/privacy}",
      "received_events_url": "https://api.github.com/users/web-flow/received_events",
      "type": "User",
      "site_admin": false
    },
    "parents": [
      {
        "sha": "93bc2fd55133e58a9a662b99b8f77720e2378b92",
        "url": "https://api.github.com/repos/chalkos/patronus-testing/commits/93bc2fd55133e58a9a662b99b8f77720e2378b92",
        "html_url": "https://github.com/chalkos/patronus-testing/commit/93bc2fd55133e58a9a662b99b8f77720e2378b92"
      },
      {
        "sha": "59bdd46316150a12835af8bb5abe87249b63cc5f",
        "url": "https://api.github.com/repos/chalkos/patronus-testing/commits/59bdd46316150a12835af8bb5abe87249b63cc5f",
        "html_url": "https://github.com/chalkos/patronus-testing/commit/59bdd46316150a12835af8bb5abe87249b63cc5f"
      }
    ]
  },
  "branches": [
    {
      "name": "patronus/59bdd46316150a12835af8bb5abe87249b63cc5f",
      "commit": {
        "sha": "40d1e58d69628950ed865a2ca5a49bcede85e990",
        "url": "https://api.github.com/repos/chalkos/patronus-testing/commits/40d1e58d69628950ed865a2ca5a49bcede85e990"
      }
    }
  ],
  "created_at": "2016-07-20T14:00:43Z",
  "updated_at": "2016-07-20T14:00:43Z",
  "repository": {
    "id": 61953147,
    "name": "patronus-testing",
    "full_name": "chalkos/patronus-testing",
    "owner": {
      "login": "chalkos",
      "id": 98429,
      "avatar_url": "https://avatars.githubusercontent.com/u/98429?v=3",
      "gravatar_id": "",
      "url": "https://api.github.com/users/chalkos",
      "html_url": "https://github.com/chalkos",
      "followers_url": "https://api.github.com/users/chalkos/followers",
      "following_url": "https://api.github.com/users/chalkos/following{/other_user}",
      "gists_url": "https://api.github.com/users/chalkos/gists{/gist_id}",
      "starred_url": "https://api.github.com/users/chalkos/starred{/owner}{/repo}",
      "subscriptions_url": "https://api.github.com/users/chalkos/subscriptions",
      "organizations_url": "https://api.github.com/users/chalkos/orgs",
      "repos_url": "https://api.github.com/users/chalkos/repos",
      "events_url": "https://api.github.com/users/chalkos/events{/privacy}",
      "received_events_url": "https://api.github.com/users/chalkos/received_events",
      "type": "User",
      "site_admin": false
    },
    "private": false,
    "html_url": "https://github.com/chalkos/patronus-testing",
    "description": "Testing https://github.com/patronus-io/patronus",
    "fork": false,
    "url": "https://api.github.com/repos/chalkos/patronus-testing",
    "forks_url": "https://api.github.com/repos/chalkos/patronus-testing/forks",
    "keys_url": "https://api.github.com/repos/chalkos/patronus-testing/keys{/key_id}",
    "collaborators_url": "https://api.github.com/repos/chalkos/patronus-testing/collaborators{/collaborator}",
    "teams_url": "https://api.github.com/repos/chalkos/patronus-testing/teams",
    "hooks_url": "https://api.github.com/repos/chalkos/patronus-testing/hooks",
    "issue_events_url": "https://api.github.com/repos/chalkos/patronus-testing/issues/events{/number}",
    "events_url": "https://api.github.com/repos/chalkos/patronus-testing/events",
    "assignees_url": "https://api.github.com/repos/chalkos/patronus-testing/assignees{/user}",
    "branches_url": "https://api.github.com/repos/chalkos/patronus-testing/branches{/branch}",
    "tags_url": "https://api.github.com/repos/chalkos/patronus-testing/tags",
    "blobs_url": "https://api.github.com/repos/chalkos/patronus-testing/git/blobs{/sha}",
    "git_tags_url": "https://api.github.com/repos/chalkos/patronus-testing/git/tags{/sha}",
    "git_refs_url": "https://api.github.com/repos/chalkos/patronus-testing/git/refs{/sha}",
    "trees_url": "https://api.github.com/repos/chalkos/patronus-testing/git/trees{/sha}",
    "statuses_url": "https://api.github.com/repos/chalkos/patronus-testing/statuses/{sha}",
    "languages_url": "https://api.github.com/repos/chalkos/patronus-testing/languages",
    "stargazers_url": "https://api.github.com/repos/chalkos/patronus-testing/stargazers",
    "contributors_url": "https://api.github.com/repos/chalkos/patronus-testing/contributors",
    "subscribers_url": "https://api.github.com/repos/chalkos/patronus-testing/subscribers",
    "subscription_url": "https://api.github.com/repos/chalkos/patronus-testing/subscription",
    "commits_url": "https://api.github.com/repos/chalkos/patronus-testing/commits{/sha}",
    "git_commits_url": "https://api.github.com/repos/chalkos/patronus-testing/git/commits{/sha}",
    "comments_url": "https://api.github.com/repos/chalkos/patronus-testing/comments{/number}",
    "issue_comment_url": "https://api.github.com/repos/chalkos/patronus-testing/issues/comments{/number}",
    "contents_url": "https://api.github.com/repos/chalkos/patronus-testing/contents/{+path}",
    "compare_url": "https://api.github.com/repos/chalkos/patronus-testing/compare/{base}...{head}",
    "merges_url": "https://api.github.com/repos/chalkos/patronus-testing/merges",
    "archive_url": "https://api.github.com/repos/chalkos/patronus-testing/{archive_format}{/ref}",
    "downloads_url": "https://api.github.com/repos/chalkos/patronus-testing/downloads",
    "issues_url": "https://api.github.com/repos/chalkos/patronus-testing/issues{/number}",
    "pulls_url": "https://api.github.com/repos/chalkos/patronus-testing/pulls{/number}",
    "milestones_url": "https://api.github.com/repos/chalkos/patronus-testing/milestones{/number}",
    "notifications_url": "https://api.github.com/repos/chalkos/patronus-testing/notifications{?since,all,participating}",
    "labels_url": "https://api.github.com/repos/chalkos/patronus-testing/labels{/name}",
    "releases_url": "https://api.github.com/repos/chalkos/patronus-testing/releases{/id}",
    "deployments_url": "https://api.github.com/repos/chalkos/patronus-testing/deployments",
    "created_at": "2016-06-25T17:03:21Z",
    "updated_at": "2016-06-25T17:03:21Z",
    "pushed_at": "2016-07-20T13:58:05Z",
    "git_url": "git://github.com/chalkos/patronus-testing.git",
    "ssh_url": "git@github.com:chalkos/patronus-testing.git",
    "clone_url": "https://github.com/chalkos/patronus-testing.git",
    "svn_url": "https://github.com/chalkos/patronus-testing",
    "homepage": null,
    "size": 4,
    "stargazers_count": 0,
    "watchers_count": 0,
    "language": null,
    "has_issues": true,
    "has_downloads": true,
    "has_wiki": true,
    "has_pages": false,
    "forks_count": 0,
    "mirror_url": null,
    "open_issues_count": 4,
    "forks": 0,
    "open_issues": 4,
    "watchers": 0,
    "default_branch": "master"
  },
  "sender": {
    "login": "chalkos",
    "id": 98429,
    "avatar_url": "https://avatars.githubusercontent.com/u/98429?v=3",
    "gravatar_id": "",
    "url": "https://api.github.com/users/chalkos",
    "html_url": "https://github.com/chalkos",
    "followers_url": "https://api.github.com/users/chalkos/followers",
    "following_url": "https://api.github.com/users/chalkos/following{/other_user}",
    "gists_url": "https://api.github.com/users/chalkos/gists{/gist_id}",
    "starred_url": "https://api.github.com/users/chalkos/starred{/owner}{/repo}",
    "subscriptions_url": "https://api.github.com/users/chalkos/subscriptions",
    "organizations_url": "https://api.github.com/users/chalkos/orgs",
    "repos_url": "https://api.github.com/users/chalkos/repos",
    "events_url": "https://api.github.com/users/chalkos/events{/privacy}",
    "received_events_url": "https://api.github.com/users/chalkos/received_events",
    "type": "User",
    "site_admin": false
  }
}
    eos
  end
end

