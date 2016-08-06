class GithubWebHookRequest
  require 'openssl'

  SECRET = ENV['GITHUB_WEBHOOK_SECRET'.freeze]

  attr :body, :headers

  def initialize(event, params = {}, request = nil)
    method_for_event = :"event_#{event}"
    @body = (respond_to?(method_for_event) ? send(method_for_event, params) : {}).to_json
    @headers = {
      # 'Request URL' => 'http://patronus.chalkos.ultrahook.com/github/webhook',
      # 'Request method' => 'POST',
      'content-type' => 'application/json',
      'Expect' => '',
      'User-Agent' => 'GitHub-Hookshot/5a08997',
      'X-GitHub-Delivery' => 'unused',
      'X-GitHub-Event' => event,
      'X-Hub-Signature' => 'sha1=' << OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), SECRET, @body)
    }
    request.headers.merge!(@headers) if request
    request.headers['RAW_POST_DATA'] = @body if request
  end

  private

  # mandatory params:
  #   :state
  #   :commit, see commit params
  #   :branches, array of branch params
  def event_status(params = {})
    params[:id] ||= 123456
    params[:sha] ||= '5b84c7138bbd1d46fa0768ab5d8f72116f5241b9'
    {
      id: params[:id],
      sha: params[:sha],
      name: 'chalkos/patronus-testing',
      target_url: nil,
      context: 'merge/patronus',
      description: nil,
      state: params[:state],
      commit: commit(params[:commit]),
      branches: params[:branches].map { |branch_params| branch(params[:sha], branch_params) },
      created_at: '2016-07-20T13:28:58Z',
      updated_at: '2016-07-20T13:28:58Z',
      repository: repository(params[:repository]),
      sender: user(params[:sender]),
    }
  end

  # minimal request
  def event_ping(params = {})
    {
      zen: 'random-string',
      hook_id: 1,
      hook: {
        id: 1,
        url: 'https://api.github.com/repos/octocat/Hello-World/hooks/1',
        test_url: 'https://api.github.com/repos/octocat/Hello-World/hooks/1/test',
        ping_url: 'https://api.github.com/repos/octocat/Hello-World/hooks/1/pings',
        name: 'web',
        events: %w(status pull_request comment_issue),
        active: true,
        config: {
          url: 'http://example.com/webhook',
          content_type: 'json'
        },
        updated_at: '2011-09-06T20:39:23Z',
        created_at: '2011-09-06T17:26:27Z'
      }
    }
  end

  # params
  #   :name
  #   :username
  #   :user_id
  #   :user_is_org
  def repository(params = {})
    name = params[:name] || 'patronus-testing'
    full_name = "#{params[:username]}/#{name}"

    user_params = {username: params[:username], id: params[:user_id]}
    if params[:user_is_org]
      user = organization(user_params)
    else
      user = user(user_params)
    end
    {
      id: params[:id],
      name: name,
      full_name: full_name,
      owner: user,
      private: false,
      html_url: "https://github.com/#{full_name}",
      description: params[:description] || '',
      fork: false,
      url: "https://api.github.com/repos/#{full_name}",
      forks_url: "https://api.github.com/repos/#{full_name}/forks",
      keys_url: "https://api.github.com/repos/#{full_name}/keys{/key_id}",
      collaborators_url: "https://api.github.com/repos/#{full_name}/collaborators{/collaborator}",
      teams_url: "https://api.github.com/repos/#{full_name}/teams",
      hooks_url: "https://api.github.com/repos/#{full_name}/hooks",
      issue_events_url: "https://api.github.com/repos/#{full_name}/issues/events{/number}",
      events_url: "https://api.github.com/repos/#{full_name}/events",
      assignees_url: "https://api.github.com/repos/#{full_name}/assignees{/user}",
      branches_url: "https://api.github.com/repos/#{full_name}/branches{/branch}",
      tags_url: "https://api.github.com/repos/#{full_name}/tags",
      blobs_url: "https://api.github.com/repos/#{full_name}/git/blobs{/sha}",
      git_tags_url: "https://api.github.com/repos/#{full_name}/git/tags{/sha}",
      git_refs_url: "https://api.github.com/repos/#{full_name}/git/refs{/sha}",
      trees_url: "https://api.github.com/repos/#{full_name}/git/trees{/sha}",
      statuses_url: "https://api.github.com/repos/#{full_name}/statuses/{sha}",
      languages_url: "https://api.github.com/repos/#{full_name}/languages",
      stargazers_url: "https://api.github.com/repos/#{full_name}/stargazers",
      contributors_url: "https://api.github.com/repos/#{full_name}/contributors",
      subscribers_url: "https://api.github.com/repos/#{full_name}/subscribers",
      subscription_url: "https://api.github.com/repos/#{full_name}/subscription",
      commits_url: "https://api.github.com/repos/#{full_name}/commits{/sha}",
      git_commits_url: "https://api.github.com/repos/#{full_name}/git/commits{/sha}",
      comments_url: "https://api.github.com/repos/#{full_name}/comments{/number}",
      issue_comment_url: "https://api.github.com/repos/#{full_name}/issues/comments{/number}",
      contents_url: "https://api.github.com/repos/#{full_name}/contents/{+path}",
      compare_url: "https://api.github.com/repos/#{full_name}/compare/{base}...{head}",
      merges_url: "https://api.github.com/repos/#{full_name}/merges",
      archive_url: "https://api.github.com/repos/#{full_name}/{archive_format}{/ref}",
      downloads_url: "https://api.github.com/repos/#{full_name}/downloads",
      issues_url: "https://api.github.com/repos/#{full_name}/issues{/number}",
      pulls_url: "https://api.github.com/repos/#{full_name}/pulls{/number}",
      milestones_url: "https://api.github.com/repos/#{full_name}/milestones{/number}",
      notifications_url: "https://api.github.com/repos/#{full_name}/notifications{?since,all,participating}",
      labels_url: "https://api.github.com/repos/#{full_name}/labels{/name}",
      releases_url: "https://api.github.com/repos/#{full_name}/releases{/id}",
      deployments_url: "https://api.github.com/repos/#{full_name}/deployments",
      created_at: '2016-06-25T17:03:21Z',
      updated_at: '2016-06-25T17:03:21Z',
      pushed_at: '2016-07-20T09:22:36Z',
      git_url: "git://github.com/#{full_name}.git",
      ssh_url: "git@github.com:#{full_name}.git",
      clone_url: "https://github.com/#{full_name}.git",
      svn_url: "https://github.com/#{full_name}",
      homepage: nil,
      size: 4,
      stargazers_count: 0,
      watchers_count: 0,
      language: nil,
      has_issues: true,
      has_downloads: true,
      has_wiki: true,
      has_pages: false,
      forks_count: 0,
      mirror_url: nil,
      open_issues_count: 4,
      forks: 0,
      open_issues: 4,
      watchers: 0,
      default_branch: 'master'
    }.merge(params[:user_is_org] ? {organization: user} : {}) # unconfirmed
  end

  # optional params:
  #   :name
  #   :sha
  def branch(default_sha, params = {})
    sha = params[:sha] || default_sha
    {
      name: params[:name] || 'a-branch',
      commit: {
        sha: sha,
        url: "https://api.github.com/repos/chalkos/patronus-testing/commits/#{sha}"
      }
    }
  end

  # mandatory params
  #   :sha
  #   :tree_sha
  #   :parent_sha (for one parent) or :parents_sha (for multiple parents)
  # optional params
  #   :message
  #   :author, see commit_author_or_committer params
  #   :use_author_as_committer
  #   :committer, see commit_author_or_committer params
  #   :comment_count
  def commit(params = {})
    author_params = params[:author] || {}
    committer_params = (params[:use_author_as_committer] ? :author : :committer) || {}
    params[:parents_sha] = [params[:parent_sha]] if params[:parent_sha]
    {
      sha: params[:sha],
      commit: {
        author: commit_author_or_committer(author_params),
        committer: commit_author_or_committer(committer_params),
        message: params[:message] || '',
        tree: {
          sha: params[:tree_sha],
          url: "https://api.github.com/repos/chalkos/patronus-testing/git/trees/#{params[:tree_sha]}"
        },
        url: "https://api.github.com/repos/chalkos/patronus-testing/git/commits/#{params[:sha]}",
        comment_count: params[:comment_count] || 0
      },
      url: "https://api.github.com/repos/chalkos/patronus-testing/commits/#{params[:sha]}",
      html_url: "https://github.com/chalkos/patronus-testing/commit/#{params[:sha]}",
      comments_url: "https://api.github.com/repos/chalkos/patronus-testing/commits/#{params[:sha]}/comments",
      author: user_chalkos,
      committer: user_web_flow,
      parents: params[:parents_sha].map { |parent_sha| commit_parent(parent_sha) },
    }
  end

  def commit_parent(sha)
    {
      sha: sha,
      url: "https://api.github.com/repos/chalkos/patronus-testing/commits/#{sha}",
      html_url: "https://github.com/chalkos/patronus-testing/commit/#{sha}"
    }
  end

  # optional params:
  #   :name
  #   :email
  #   :date
  def commit_author_or_committer(params = {})
    {
      name: params[:name] || 'GitHub',
      email: params[:email] || 'noreply@github.com',
      date: params[:date] || '2016-07-20T09:20:07Z',
    }
  end

  # mandatory params:
  #   :id
  #   :username
  # optional params:
  #   :gravatar_id, defaults to ''
  #   :admin, defaults to false
  #   :type, defaults to 'User'
  def user(params = {})
    params[:gravatar_id] ||= ''
    params[:admin] ||= false
    {
      login: params[:username],
      id: params[:id],
      gravatar_id: params[:gravatar_id],
      type: params[:type] || 'User',
      site_admin: params[:admin],
      avatar_url: "https://avatars.githubusercontent.com/u/#{params[:id]}?v=3",
      url: "https://api.github.com/users/#{params[:username]}",
      html_url: "https://github.com/#{params[:username]}",
      followers_url: "https://api.github.com/users/#{params[:username]}/followers",
      following_url: "https://api.github.com/users/#{params[:username]}/following{/other_user}",
      gists_url: "https://api.github.com/users/#{params[:username]}/gists{/gist_id}",
      starred_url: "https://api.github.com/users/#{params[:username]}/starred{/owner}{/repo}",
      subscriptions_url: "https://api.github.com/users/#{params[:username]}/subscriptions",
      organizations_url: "https://api.github.com/users/#{params[:username]}/orgs",
      repos_url: "https://api.github.com/users/#{params[:username]}/repos",
      events_url: "https://api.github.com/users/#{params[:username]}/events{/privacy}",
      received_events_url: "https://api.github.com/users/#{params[:username]}/received_events",
    }
  end

  # see user
  def organization(params = {})
    user(params.merge({type: 'Organization'}))
  end

  def user_web_flow
    user({
      id: 19864447,
      username: 'web-flow',
    })
  end

  def user_chalkos
    user({
      id: 98429,
      username: 'chalkos'
    })
  end

  def user_bundlerbot
    user({
      id: 13614622,
      username: 'bundlerbot'
    })
  end
end