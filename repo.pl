#!/usr/local/bin/perl
use Term::ANSIColor;

$command = shift;

if ( $command =~ m/status/ ) {
    &forall("git status");
}

if ( $command =~ m/tag/ ) {
	$tag = shift;
	$branch = shift;
    &forall("git tag $tag $branch");
}

if ( $command =~ m/forall/ ) {
	$stuff = @ARGV;
	$command = "";
	for my $arg ( @ARGV ) {
		$command = $command . " " . $arg;
	}
    &forall($command);
}

if ( $command =~ m/folders/ ) {
	$stuff = @ARGV;
	$command = "";
	for my $arg ( @ARGV ) {
		$command = $command . " " . $arg;
	}
    &folders($command);
}

if ( $command =~ m/close/ ) {
    &close(shift, shift, shift);
}

if ( $command =~ m/merge/ ) {
    &merge();
}

if ( $command =~ m/rebase/ ) {
    &rebase(shift);
}

if ( $command =~ m/help/ ) {
    
}

sub forall {
    local $gitcommand = $_[0];
    opendir( DIR, "." ) or die "Can't open the current directory: $!\n";

    # read file/directory names in that directory into @names
    @names = readdir(DIR) or die "Unable to read current dir:$!\n";
    closedir(DIR);

    foreach $name (@names) {
        next if ( $name eq "." );     # skip the current directory entry
        next if ( $name eq ".." );    # skip the parent  directory entry

        if ( -d $name ) {             # is this a directory?

            opendir( SUBDIR, $name )
              or die "Can't open the current directory: $!\n";
            @subdirnames = readdir(SUBDIR)
              or die "Unable to read current dir:$!\n";
            closedir(DIR);
            my %subdirnameshash = map { $_ => 1 } @subdirnames;
            if ( exists( $subdirnameshash{".git"} ) ) {
                printf "%s\n", colored( "\nfound a git repo in $name\n", 'green' );
                system("cd $name; $gitcommand; cd ..");
            }

            next;    # can skip to the next name in the for loop
        }
    }
}

sub folders {
    local $gitcommand = $_[0];
    opendir( DIR, "." ) or die "Can't open the current directory: $!\n";

    # read file/directory names in that directory into @names
    @names = readdir(DIR) or die "Unable to read current dir:$!\n";
    closedir(DIR);

    foreach $name (@names) {
        next if ( $name eq "." );     # skip the current directory entry
        next if ( $name eq ".." );    # skip the parent  directory entry

        if ( -d $name ) {             # is this a directory?

            opendir( SUBDIR, $name )
              or die "Can't open the current directory: $!\n";
            @subdirnames = readdir(SUBDIR)
              or die "Unable to read current dir:$!\n";
            closedir(DIR);
            my %subdirnameshash = map { $_ => 1 } @subdirnames;
            system("cd $name; $gitcommand; cd ..");
            next;    # can skip to the next name in the for loop
        }
    }
}

sub close {
    $base = shift;
    $branch = shift;
	$flags = shift;
    
    if ($base eq ""){
        printf "%s\n", colored("Usage: repo close <base> <branch>\nProvide an argument.\nAbotring.",'red');
        die("InvalidParameterException:-)");
    }
    

    &check_index();

    %branches = ();
    $branches{$branch} = $base;
	if ( $branch =~ m/develop|online|odessa|mogadischu|stabi|puli|duesseldorf/ ) {
            
    } else { if ( $flags =~ m/--auto/ ){
		&rebase_topic_branches(%branches);
	}}

    $failed = system("git checkout $base");
    if ($failed) {
        die("wtf\n");
    }

    @commits = split( /\n/, readpipe("git log $base..$branch --oneline") );
    my $option = "";
    if (@commits > 1) {
        $option = "--no-ff";
        $ending = "s";
    }

    $amount = @commits;
    print "merging $amount commit$ending\n";
    #$filepath = $ENV{"HOME"} . "/.gitmessage.txt";
	#http://stackoverflow.com/questions/3357280/print-commit-message-of-a-given-commit-in-git
	$merged_commit_messages = readpipe("git log $base..$branch --format=%B-------------------------------------------------------------- --no-merges");
    $commitmsg = "Merge $branch into $base\n\n$merged_commit_messages";
	$commitmsg =~ s/\"/\ /g;
	
	#die("git merge $branch $option --edit -m \"$commitmsg\"");
	$merge_command = "git merge $option --edit -m \"$commitmsg\" $branch";
    $failed = system("$merge_command");
    if ($failed) {
		if ( $flags =~ m/--auto/ ){
		    system("git merge --abort");
		} else {
		    printf "%s\n", colored("Conflicts!",'red');
		}
    } else {
	    if ( $branch =~ m/develop|online|odessa|mogadischu|stabi|puli|duesseldorf/ ) {
            
		} else {if ($flags =~ m/--auto/) {
		    system("git branch -d $branch");
		}}
    }
}

sub merge {
    $branch = readpipe("git symbolic-ref --short HEAD");

    #maps branch name to it's base
    %branches = ();
    
    $list  = readpipe("git branch");
    @lines = split( /\n/, $list );
    
    foreach my $branch_to_rebase (@lines) {
    	$branch_to_rebase =~ s/[\*]//;    # remove *
    	$branch_to_rebase =~ s/^\s+//;    # remove leading whitespace
    	$branch_to_rebase =~ s/\s+$//;    # remove trailing whitespace
    	$base = "develop";

    	$mergebase = readpipe("git merge-base develop $branch_to_rebase");
    	$develop_head = readpipe("git rev-parse develop");

	##TODO list with repoignore branches
    	if ( $branch_to_rebase =~ m/develop|online|odessa|mogadischu|stabi|puli|duesseldorf/ ) {
    		print "skipping $branch_to_rebase\n";
    	} else {
            if ($mergebase =~ m/$develop_head/ ) {
    		    $branches{$branch_to_rebase} = $base;
    	    } else {
    	    	##TODO remove this or make optional when repoignore list is there
    		    print "skipping $branch_to_rebase because it is behind develop\n";
    	    }
    	}
    }
    
    &check_index();
    
    $failed = system("git checkout -b merge");
    if ($failed) {
    	system("git checkout merge");
    }
    system("git reset develop --hard");
    
    my @unwanted;
    for my $base ( values(%branches) ) {
    	if ( $branches{$base} ) {
    		push @unwanted, $base;
    	}
    }
    delete @branches{@unwanted};
    
    @branches_for_merge = keys(%branches);
    my @failed_to_merge;
    
    $octopus_failed = system("git merge --no-ff @branches_for_merge");
    if ($octopus_failed) {
    	print "octopus failed, merge one by one\n";
    	system("git reset HEAD --hard");
    	for my $branch (@branches_for_merge) {
    		$failed = system("git merge --no-ff $branch");
    		if ($failed) {
    			system("git merge --abort");
    			push @failed_to_merge, $branch;
    		}
    	}
    }
    print "merged all branches\n";
    print "failed to merge: @failed_to_merge \n"
}

sub rebase {
    local $base = $_[0];
    
    if ($base eq ""){
        printf "%s\n", colored("Usage: repo rebase <base>\nProvide an argument.\nAbotring.",'red');
        die("InvalidParameterException:-)");
    }
    
    &check_index();
    
    ##### INIT STUFF #########################
    
    $branch   = readpipe("git symbolic-ref --short HEAD");
    $remotes  = readpipe("git remote");
    %branches = &build_branches_map($base);
    
    ##### DO STUFF ###########################
    &rebase_topic_branches(%branches);
    
    system("git checkout $branch");
    
    if ( $remotes =~ m/origin/ ) {
    	printf "%s\n", colored("found origin, pushing $base", 'green');
    	&push_and_pull($base);
    }
    
    if ( $remotes =~ m/backup/ ) {
    	print "found backup, pushing all branches\n";
    	system("git push backup $base -f");
    	for my $key ( keys(%branches) ) {
    		system("git push backup $key -f");
    	}
    }
}

######## LEVEL 2 SUBROUTINES ######################################################

sub push_and_pull {
	local $branch = $_[0];

	#check if branch on the server has moved
	#if yes, attempt to pull. Merge to the develop shoud be discouraged
	#for now just do not use -f
	my $push_failed = system("git push origin $branch");
	if ($push_failed) {
		print "somebody else has updated $branch, attepmting to merge";
		my $pull_failed = system("git pull origin $branch");
		if ($pull_failed) {
			system("git reset HEAD --hard");
			die("push failed, we must have diverged!");
		}
	}

	print "Files have been changed:\n";
	system("git diff develop^..develop --name-status");

	print "Commit messages:\n";
	system("git log develop^..develop");
}

sub build_branches_map {
	local $base = $_[0];
	%branches = ();
	@lines = split( /\n/, readpipe("git branch --no-merged") );
	foreach my $branch_to_rebase (@lines) {
		$branch_to_rebase =~ s/[\*]//;    # remove *
		$branch_to_rebase =~ s/^\s+//;    # remove leading whitespace
		$branch_to_rebase =~ s/\s+$//;    # remove trailing whitespace
		##TODO list with repoignore branches
		if ( $branch_to_rebase =~ m/norebase|develop|online|odessa|mogadischu|stabi|puli|duesseldorf/ ) {
			printf "%s\n", colored("skipping $branch_to_rebase",'magenta');
		}
		else {
			$branches{$branch_to_rebase} = $base;
		}
	}
	%branches;
}

sub rebase_topic_branches (\%) {
	my (%p_branches) = @_;

	#TODO find out how we can rebase bases first
	for my $key ( keys(%p_branches) ) {
		my $branch_to_rebase = $key;
		my $base             = $p_branches{$key};

		printf "%s\n", colored("rebasing $branch_to_rebase on top of $base", 'cyan');
		system("git checkout $branch_to_rebase");

		my $rebase_failed = system("git rebase $base");
		if ($rebase_failed) {
		        printf "%s\n", colored("automatic rebase failed, aborting",'red');
			system("git rebase --abort");
			next;
		}
	}
	print "rebased all branches\n";
}

sub check_index {
    #check index, if uncommited changes exist - abort
    my $dirty = system("git diff-index --quiet HEAD");
    if ($dirty) {
        die("Working dir is dirty, commit or stash!\n");
    }
}
