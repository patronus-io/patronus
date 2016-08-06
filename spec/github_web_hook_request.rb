class GithubWebHookRequest
  require 'openssl'

  autoload :Ping,   'github_web_hook_request/ping'
  autoload :Status, 'github_web_hook_request/status'

  SECRET = ENV['GITHUB_WEBHOOK_SECRET'.freeze]

  attr :body, :event

  def initialize(event, request = nil)
    @event = event
    @body = (@body || {}).to_json
    add_to_request(request) if request
  end

  def add_to_request(request)
    request.headers.merge!(headers) if request
    request.headers['RAW_POST_DATA'] = @body if request
  end

  def headers
    @headers ||= {
      # 'Request URL' => 'http://patronus.chalkos.ultrahook.com/github/webhook',
      # 'Request method' => 'POST',
      'content-type' => 'application/json',
      'Expect' => '',
      'User-Agent' => 'GitHub-Hookshot/5a08997',
      'X-GitHub-Delivery' => 'unused',
      'X-GitHub-Event' => @event,
      'X-Hub-Signature' => 'sha1=' << OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), SECRET, @body)
    }
  end

  private

  def repository(id:, name:, full_name:, username:, user_id:, user_is_organization: false, description: '')
    user = user(username: username, id: user_id, type: user_is_organization ? 'Organization' : 'User')
    {
      id: id,
      name: name,
      full_name: full_name,
      owner: user,
      private: false,
      html_url: "https://github.com/#{full_name}",
      description: description,
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
    }.merge(user_is_organization ? {organization: user} : {}) # unconfirmed
  end

  def branch(sha:, name:, repo_full_name:)
    {
      name: name,
      commit: {
        sha: sha,
        url: "https://api.github.com/repos/#{repo_full_name}/commits/#{sha}"
      }
    }
  end

  # author uses arguments from #user and #commit_author_or_committer
  # committer uses arguments from #user and #commit_author_or_committer
  # if use_author_as_committer is true, committer is ignored and the value from user is used
  def commit(repo_full_name:, commit_parents: [], commit_parent_sha: '', sha:, tree_sha:, author:, committer:, author_is_committer: false, comment_count: 0, message: '')
    committer = author_is_committer ? author : committer
    commit_parents ||= [{sha: commit_parent_sha}]
    {
      sha: sha,
      commit: {
        author: commit_author_or_committer(commit_author_or_committer_params(author)),
        committer: commit_author_or_committer(commit_author_or_committer_params(committer)),
        message: message,
        tree: {
          sha: tree_sha,
          url: "https://api.github.com/repos/#{repo_full_name}/git/trees/#{tree_sha}"
        },
        url: "https://api.github.com/repos/#{repo_full_name}/git/commits/#{sha}",
        comment_count: comment_count
      },
      url: "https://api.github.com/repos/#{repo_full_name}/commits/#{sha}",
      html_url: "https://github.com/#{repo_full_name}/commit/#{sha}",
      comments_url: "https://api.github.com/repos/#{repo_full_name}/commits/#{sha}/comments",
      author: user(user_params(author)),
      committer: user(user_params(committer)),
      parents: commit_parents.map { |parent| commit_parent(default_full_name: repo_full_name, **parent) },
    }
  end

  # only the sha is needed, since default_full_name is set in #commit
  def commit_parent(sha:, full_name:, default_full_name:)
    full_name ||= default_full_name
    {
      sha: sha,
      url: "https://api.github.com/repos/#{full_name}/commits/#{sha}",
      html_url: "https://github.com/#{full_name}/commit/#{sha}"
    }
  end

  def commit_author_or_committer(name: 'GitHub', email: 'noreply@github.com', date: '2016-07-20T09:20:07Z')
    {name: name, email: email, date: date}
  end

  # valid user examples:
  #   username web_flow with id 19864447
  #   username chalkos with id 98429
  #   username bundlerbot with id 13614622
  def user(id:, username:, type: 'User', gravatar_id: '')
    {
      login: username,
      id: id,
      gravatar_id: gravatar_id,
      type: type,
      site_admin: false,
      avatar_url: "https://avatars.githubusercontent.com/u/#{id}?v=3",
      url: "https://api.github.com/users/#{username}",
      html_url: "https://github.com/#{username}",
      followers_url: "https://api.github.com/users/#{username}/followers",
      following_url: "https://api.github.com/users/#{username}/following{/other_user}",
      gists_url: "https://api.github.com/users/#{username}/gists{/gist_id}",
      starred_url: "https://api.github.com/users/#{username}/starred{/owner}{/repo}",
      subscriptions_url: "https://api.github.com/users/#{username}/subscriptions",
      organizations_url: "https://api.github.com/users/#{username}/orgs",
      repos_url: "https://api.github.com/users/#{username}/repos",
      events_url: "https://api.github.com/users/#{username}/events{/privacy}",
      received_events_url: "https://api.github.com/users/#{username}/received_events",
    }
  end

  # see user
  def organization(id:, username:, gravatar_id: '')
    user(id: id, username: username, type: 'Organization', gravatar_id: gravatar_id)
  end

  # returns the params hash containing only arguments allowed in #user
  def user_params(params)
    filter = method(:user).parameters.select { |ps| [:key, :keyreq].include? ps.first }.map(&:last)
    params.slice(filter)
  end

  # returns the params hash containing only arguments allowed in #commit_author_or_committer
  def commit_author_or_committer_params(params)
    filter = method(:commit_author_or_committer).parameters.select { |ps| [:key, :keyreq].include? ps.first }.map(&:last)
    params.slice(filter)
  end
end