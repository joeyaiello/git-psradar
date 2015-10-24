<#

.SYNOPSIS

   A heads up display for git. A port of https://github.com/michaeldfallen/git-radar

.DESCRIPTION

    Provides an at-a-glance information about your git repo.

.LINK

   https://github.com/vincpa/git-psradar

#>
$upArrow 	= ([Convert]::ToChar(9650))
$rightArrow	= ([Convert]::ToChar(26))

function Get-StatusString($porcelainString) {
	$results = @{
		Staged = @{
			Modified = 0;
			Deleted = 0;
			Added = 0;
			Renamed = 0;
			Copied = 0;
		};
		Unstaged = @{
			Modified = 0;
			Deleted = 0;
			Renamed = 0;
			Copied = 0;
		};
		Untracked = @{
			Added = 0;
		};
		Conflicted = @{
			ConflictUs = 0;
			ConflictThem = 0;
			Conflict = 0;
		}
	}

	if ($porcelainString -ne '' -and $porcelainStatus -ne $null) {

		$porcelainString.Split([Environment]::NewLine) | % {
			if ($_[0] -eq 'R') { $results.Staged.Renamed++; }
			elseif ($_[0] -eq 'A') { $results.Staged.Added++ }
			elseif ($_[0] -eq 'D') { $results.Staged.Deleted++ }
			elseif ($_[0] -eq 'M') { $results.Staged.Modified++ }
			elseif ($_[0] -eq 'C') { $results.Staged.Copied++ }

			if ($_[1] -eq 'R') { $results.Unstaged.Renamed++ }
			elseif ($_[1] -eq 'D') { $results.Unstaged.Deleted++ }
			elseif ($_[1] -eq 'M') { $results.Unstaged.Modified++ }
			elseif ($_[1] -eq 'C') { $results.Unstaged.Copied++ }
			if($_[1] -eq '?') { $results.Untracked.Added++ }

			elseif ($_[1] -eq 'U') { $results.Conflicted.ConflictUs++ }
			elseif ($_[1] -eq 'T') { $results.Conflicted.ConflictThem++ }
			elseif ($_[1] -eq 'B') { $results.Conflicted.Conflict++ }
		}
	}
	return $results
}

function Get-Staged($status, $color, $showNewFiles, $onlyShowNewFiles) {
	$hasChanged = $false;
	$hasChanged = (Write-GitStatus $status.Added 'A' $color) -or $hasChanged
	$hasChanged = (Write-GitStatus $status.Renamed 'R' $color) -or $hasChanged
	$hasChanged = (Write-GitStatus $status.Deleted 'D' $color) -or $hasChanged
	$hasChanged = (Write-GitStatus $status.Modified 'M' $color) -or $hasChanged
	$hasChanged = (Write-GitStatus $status.Copied 'C' $color) -or $hasChanged
	$hasChanged = (Write-GitStatus $status.ConflictUs 'U' $color) -or $hasChanged
	$hasChanged = (Write-GitStatus $status.ConflictThem 'T' $color) -or $hasChanged
	$hasChanged = (Write-GitStatus $status.Conflict 'B' $color) -or $hasChanged
	if ($hasChanged) {
		Write-Host ' ' -NoNewline
	}
}

function Write-GitStatus($count, $symbol, $color) {
	if ($count -gt 0) {
		Write-Host $count -ForegroundColor White -NoNewline
		Write-Host $symbol -ForegroundColor $color -NoNewline
		return $true;
	}
	return $false;
}

# Does not raise an error when outside of a git repo
function Test-GitRepo($directoryInfo = ([System.IO.DirectoryInfo](Get-Location).Path)) {

	if ($directoryInfo -eq $null) { return }

	$gs = $directoryInfo.GetDirectories(".git");

	if ($gs.Length -eq 0)
	{
		return Test-GitRepo($directoryInfo.Parent);
	}
	return $directoryInfo.FullName;
}

function Show-PsRadar {

    $currentPath = ([System.IO.DirectoryInfo](Get-Location).Path)

    $gitRepoPath = Test-GitRepo;

    if($gitRepoPath -ne $null) {

        $gitResults = @{
		    GitRoot = git rev-parse --show-toplevel;
			PorcelainStatus = git status --porcelain;
        }

  	    $currentBranchString = (git branch --contains HEAD)

        if ($currentBranchString -ne $NULL) {

            $currentBranch = $currentBranchString.Split([Environment]::NewLine)[0]

            if ($currentBranch[2] -eq '(') {
                $branch = $currentBranch.Substring(2)
            } else {
                $branch = '(' + $currentBranch.Substring(2) + ')'
            }

            $gitRoot = $gitResults.GitRoot
            $repoName = $gitRoot.Substring($gitRoot.LastIndexOf('/') + 1) + $currentPath.FullName.Replace('\', '/').Substring($gitRoot.Length)
            $porcelainStatus = $gitResults.PorcelainStatus

    	    Write-Host $rightArrow -NoNewline -ForegroundColor Green
    	    Write-Host " $repoName/" -NoNewline -ForegroundColor DarkCyan
    	    Write-Host " git:$branch" -NoNewline -ForegroundColor DarkGray

    	    $status = Get-StatusString $porcelainStatus

    	    Get-Staged $status.Conflicted Yellow
    	    Get-Staged $status.Staged Green
    	    Get-Staged $status.Unstaged Magenta
    	    Get-Staged $status.Untracked Gray

            return $true
        }
    }
    
    return $false
}

Export-ModuleMember -Function Show-GitPsRadar, Test-GitRepo -WarningAction SilentlyContinue -WarningVariable $null

# Get the existing prompt function
$originalPrompt = (Get-Item function:prompt).ScriptBlock

function global:prompt {

	# Change the prompt as soon as we enter a git repository
	if ((Test-GitRepo) -and (Show-PsRadar)) {
		return "$ "
	} else {
		Invoke-Command $originalPrompt
	}
}
