# Modified: Symboxtra Software
# Author: Sankarsan Kampa (a.k.a. k3rn31p4nic)
# License: MIT

$WEBHOOK_VERSION="2.0.0.0"

$STATUS=$args[0]
$WEBHOOK_URL=$args[1]
$CURRENT_TIME=[int64](([datetime]::UtcNow)-(get-date "1/1/1970")).TotalSeconds

$OS_NAME="Windows"






if (!$WEBHOOK_URL) {
  Write-Output "WARNING!!"
  Write-Output "You need to pass the WEBHOOK_URL environment variable as the second argument to this script."
  Write-Output "For details & guide, visit: https://github.com/symboxtra/appveyor-discord-webhook"
  Exit
}

Write-Output "[Webhook]: Sending webhook to Discord..."

Switch ($STATUS) {
  "success" {
    $EMBED_COLOR=3066993
    $STATUS_MESSAGE="Passed"
    Break
  }
  "failure" {
    $EMBED_COLOR=15158332
    $STATUS_MESSAGE="Failed"
    Break
  }
  default {
  $EMBED_COLOR=0
    Write-Output "Status Unknown"
    Break
  }
}
$AVATAR="https://upload.wikimedia.org/wikipedia/commons/thumb/b/bc/Appveyor_logo.svg/256px-Appveyor_logo.svg.png"

if (!$env:APPVEYOR_REPO_COMMIT) {
    $env:APPVEYOR_REPO_COMMIT="$(git log -1 --pretty="%H")"
}

$AUTHOR_NAME="$(git log -1 "$env:APPVEYOR_REPO_COMMIT" --pretty="%aN")"
$COMMITTER_NAME="$(git log -1 "$env:APPVEYOR_REPO_COMMIT" --pretty="%cN")"
$COMMIT_SUBJECT="$(git log -1 "$env:APPVEYOR_REPO_COMMIT" --pretty="%s")"
$COMMIT_MESSAGE="$(git log -1 "$env:APPVEYOR_REPO_COMMIT" --pretty="%b")"
$COMMIT_TIME="$(git log -1 "$env:APPVEYOR_REPO_COMMIT" --pretty="%ct")"

if ($AUTHOR_NAME -eq $COMMITTER_NAME) {
    $CREDITS="$AUTHOR_NAME authored & committed"
}
else {
    $CREDITS="$AUTHOR_NAME authored & $COMMITTER_NAME committed"
}

# Calculate approximate build time based on commit
$BUILD_TIME=$CURRENT_TIME-$COMMIT_TIME
$TIME_STAMP=$([timespan]::fromseconds($BUILD_TIME))
$DISPLAY_TIME=$("{0:mm:ss}" -f ([datetime]$TIME_STAMP.Ticks))

# Regex match co-author names
if ($COMMIT_MESSAGE -match 'Co-authored-by:')
{
    [array] $RESULTS=[regex]::Matches("$COMMIT_MESSAGE", '\w+\s\w+')
    if ($RESULTS.Count -gt 0)
    {
        $CO_AUTHORS=$RESULTS.Value
    }
    $CO_AUTHORS = $CO_AUTHORS -join ', '
}
else
{
    $CO_AUTHORS="None"
}

# Replace git hashes in merge commits
if ($COMMIT_SUBJECT -match 'Merge \w{40}\b into \w{40}\b')
{
    $IS_PR=True
    [array] $RESULTS=[regex]::Matches("$COMMIT_SUBJECT", '\w{40}\b')
    foreach ($MATCH in $RESULTS)
    {
        $HASH=$MATCH.Value
        $BRANCH_NAME="$(git name-rev "$HASH" --name-only)"
        if ($BRANCH_NAME)
            $COMMIT_SUBJECT="$COMMIT_SUBJECT" -replace "$HASH", "$BRANCH_NAME"
    }
}

# Remove repo owner: symboxtra/project -> project
$REPO_NAME=$env:APPVEYOR_REPO_NAME -replace '^[^/]*\/', ''

# Create appropriate link
if ($env:APPVEYOR_PULL_REQUEST_NUMBER -Or $IS_PR) {
  $URL="https://github.com/$env:APPVEYOR_REPO_NAME/pull/$env:APPVEYOR_PULL_REQUEST_NUMBER"
}
else {
  $URL="https://github.com/$env:APPVEYOR_REPO_NAME/commit/$env:APPVEYOR_REPO_COMMIT"
}

$TIMESTAMP="$(Get-Date -format s)Z"
$WEBHOOK_DATA="{
  ""username"": """",
  ""avatar_url"": ""$AVATAR"",
  ""embeds"": [ {
    ""color"": $EMBED_COLOR,
    ""author"": {
      ""name"": ""#$env:APPVEYOR_BUILD_NUMBER - $REPO_NAME - $STATUS_MESSAGE"",
      ""url"": ""https://ci.appveyor.com/project/$env:APPVEYOR_ACCOUNT_NAME/$env:APPVEYOR_PROJECT_SLUG/build/$env:APPVEYOR_BUILD_VERSION"",
      ""icon_url"": ""$AVATAR""
    },
    ""title"": ""$COMMIT_SUBJECT"",
    ""url"": ""$URL"",
    ""description"": ""$COMMIT_MESSAGE\n\n$CREDITS"",
    ""fields"": [
      {
      	""name"": ""OS"",
      	""value"": ""$OS_NAME"",
      	""inline"": true
      },
      {
        ""name"": ""Build Time"",
        ""value"": ""~$DISPLAY_TIME"",
        ""inline"": true
      },
      {
      	""name"": ""Build ID"",
      	""value"": ""${env:APPVEYOR_BUILD_NUMBER}CI"",
      	""inline"": true
      },
      {
        ""name"": ""Commit"",
        ""value"": ""[``$($env:APPVEYOR_REPO_COMMIT.substring(0, 7))``](https://github.com/$env:APPVEYOR_REPO_NAME/commit/$env:APPVEYOR_REPO_COMMIT)"",
        ""inline"": true
      },
      {
        ""name"": ""Branch/Tag"",
        ""value"": ""[``$env:APPVEYOR_REPO_BRANCH``](https://github.com/$env:APPVEYOR_REPO_NAME/tree/$env:APPVEYOR_REPO_BRANCH)"",
        ""inline"": true
      },
      {
        ""name"": ""Co-Authors"",
        ""value"": ""$CO_AUTHORS"",
        ""inline"": true
      }
    ],
    ""footer"": {
        ""text"": ""v$WEBHOOK_VERSION""
      },
    ""timestamp"": ""$TIMESTAMP""
  } ]
}"

Invoke-RestMethod -Uri "$WEBHOOK_URL" -Method "POST" -UserAgent "AppVeyor-Webhook" `
  -ContentType "application/json" -Header @{"X-Author"="k3rn31p4nic#8383"} `
  -Body $WEBHOOK_DATA

Write-Output "[Webhook]: Successfully sent the webhook."
