# patronus

### keep your integration branch green

Patronus keeps your integration branch(es) green by monitoring your pull requests. When a pull request is reviewed and approved by a team member, Patronus creates a merge commit, runs the tests, and fast-forwards if the tests pass. Simple.

## Architecture

At a high level, Patronus should need to store no state for any particular build. The only persisted data should be ACL/Auth-related. Everything else should be done in response to webhooks/page views.

Patronus should not be seek to serve a million users in a single instance. Instead, it should be incredibly simple to deploy to heroku for an individual/team.

Also, commenting on PRs is rude. Patronus shouldn't do that, and optionally could delete the command comments. (If configured to comment, allow also configuring the GH user to do it as.)

### Persisted Data

#### Project

Has an associated oauth token to use (the person who authorized). List of reviewers.

### Webhooks

#### Pull Request

Optionally, run a test against incoming PRs.

#### Pull Request Issue Comment

If is approval (`@Patronus :+1:`) by an admin, create a new ref (`Patronus-HEAD_SHA`) from master, merge in the approved commit. In the merge commit message, track the exact message, so we know what actions to take once testing is finished. Also, create a pending status for the PR ref, with the URL pointing to the PR/commit page on Patronus for that commit.

Likewise, if `:+1: branch=branch_name`.

Likewise, if `test`. But this wont cause the target branch to be fast-forwarded to the merge even if it passes.

If `:-1:`, set Marhsal's status for the merged ref to failed.

#### Status

Get the combined status for the ref. If it passed, introspect the commit message. If it has a `@Patronus :+1:`, fast forward the target branch to that commit.

Set the build status of the PR commit to the result of that ref. If configured, send a slack message / post a comment on the PR (and then optionally delete it :P).

If a Patronus branch, delete it.

### Web Pages

#### Project

List the admin users (and modify that list, if an admin. Use GH auth.) Optionally, be able to set a GH auth token / name / email for the merge commits?

#### PR

List all builds for that PR. Optionally, store a set of junit reports that could be rendered (per built commit).