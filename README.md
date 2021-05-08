# cancel-if

**INTERNAL USE ONLY:** This GitHub action is not intended for general use.  The only reason why this repo is public is because GitHub requires it.

Cancels the workflow on a condition (e.g. the workflow has been queued for too long).  This works by 
using the GitHub REST API to cancel the workflow when the condition is satisfied.  Note that the
action never returns when the workflow is canceled; we rely on the runner to abort the action and
workflow processes.

Note that this requires access to the current user's master 1Password to retrieve the GITHUB_PAT,
so you should run the **environment** action first.

## Examples

**Cancel the workflow when it's been queued for more than the 45 minutes:**
```
steps:

# We need this so that the master password will be loaded as an environment variable.

- uses: nforgeio-actions/environment
  with:
    master-password: ${{ secrets.DEVBOT_MASTER_PASSWORD }}
    
# Cancel the workflow when it's been queued for 45 minutes or longer.

- using: nforgeio/cancel-if@master
  with:
    queued-minutes-exceeded: 45
```
