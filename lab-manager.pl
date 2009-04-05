#!/opt/local/bin/perl


# TODO
# 
# reclaim app_ids in the event that we're deleting a pod in single shot
# operation


use Getopt::Long;
use File::Path;
use POSIX qw(strftime);

my %opts = ();
my %dir_hash = ();

my $iou_base     = "/home/iou";
my $iourc        = "$iou_base/IOURC";
my $wrapper_src  = "$iou_base/bin/wrapper";
my $labdir       = "$ENV{HOME}/telco-labs";
my $appid_db     = "$ENV{HOME}/.app_id.db";
my $bin_tar      = "/usr/bin/tar";

my $cwd = $ENV{PWD};
my $now_string = strftime "%Y%m%d-%H%M%S", localtime;


GetOptions('pod_id=s'     => \$opts{pod_id},  
           'lab_dir=s'    => \$opts{lab_dir},	 
	   'lab_image=s'  => \$opts{keep_recent},	
	   'action=s'     => \$opts{action},	
	   'start_port=s' => \$opts{start_port},	
	   'template=s'   => \$opts{template}	,
	   'batch'        => \$opts{batch},	
	   'setup'        => \$opts{setup},	
	   'reset_appid'  => \$opts{reset_appid},
	   'pod_count=s'  => \$opts{pod_count},	
	  );	


if (defined($opts{setup})) {
    mkpath("$labdir/logs", 0, 0755);
    mkpath("$labdir/pods", 0, 0755);
    mkpath("$labdir/archives", 0, 0755);
    &initAppIdDb($appid_db); 
    print "-- instructor setup complete\n";
}


if ( defined($opts{reset_appid})) { 
    &initAppIdDb($appid_db); 
}


if (! -d $labdir) {
    print <<EOF;
*** ATTENTION ***

this looks like the first time that this tool has been run.  you do not
have the necessary directory structure in place.  please rerun this tool
with the --setup flag to create the necessary directory structure.

this will create the following directories for you.

  $labdir/pods
  the location for the individual pods used in classes

  $labdir/logs
  the location for the log files associated with your classes and the
  administrative actions taken over the course of the class

  $labdir/archives
  the location for archived pods generated with the archive action

EOF

exit;

}


#---------------------------------------------------------------------
# sanity check the args for the action being taken
#
# initialization actions
if ( $opts{action} eq "init" && !defined($opts{batch}) ) {
    # running in single shot mode
    if ( ($opts{start_port} >= 2000) && 
	 ($opts{template} ne "") && 
	 ($opts{pod_id} ne "")
	) {
	my ($last_port) = 
	    &initPod($opts{pod_id}, $opts{template}, $opts{start_port});
	print "pod init complete - check the log for more details:\n";
	print "  $labdir/logs/lab-$opts{action}-log-$now_string.log\n";
	exit();
    } else {
	&printUsage();
	exit();
    }
} elsif ($opts{action} eq "init" && defined($opts{batch}) && $opts{pod_count} ne "") {
    # running in batch mode
    if ( ($opts{start_port} >= 2000) && 
	 ($opts{template} ne "") && 
	 ($opts{pod_count} >= 2) && 
	 ($opts{pod_id} ne "")
	) {
	&batchInit($opts{pod_id}, $opts{template}, $opts{start_port}, $opts{pod_count});
	print "batch pod init complete - check the log for more details:\n";
	print "  $labdir/logs/lab-$opts{action}-log-$now_string.log\n";
	exit();
    } else {
	&printUsage();
	exit();
    }
}

# startup actions
if ($opts{action} eq "start" && !defined($opts{batch}) && $opts{pod_id} ne "")  {    
    # running in single shot mode
    
    &startPod($opts{pod_id});
    print "pod start ($opts{pod_id}) complete\n";
    exit();

} 

if ( $opts{action} eq "start" && defined($opts{batch}) ) {
    # startup all of the pods in the lab_dir

    print "starting pods ...\n";
    &batchStart();
    print "pod start complete\n"; 
    exit();
} 


# pod halting actions
if ($opts{action} eq "stop" && !defined($opts{batch}) && $opts{pod_id} ne "")  {    
    # running in single shot mode
    
    &stopPod($opts{pod_id});
    print "pod stop ($opts{pod_id}) complete\n";
    exit();

} 

if ( $opts{action} eq "stop" && defined($opts{batch}) ) {
    # shutting down all of the pods in the pod directory

    print "stopping pods ...\n";
    &batchStop();
    print "pod stop complete\n"; 
    exit();
} 


if ( $opts{action} eq "delete" && !defined($opts{batch}) ) {
    # running in single shot mode
    &deletePod($opts{pod_id});
    print "pod [$opts{pod_id}] deleted\n";
	
    exit();

} elsif ( $opts{action} eq "delete" && defined($opts{batch}) ) {
    # running in batch mode

    print "we're deleting lots of something\n";
    exit();
} else {
    &printUsage();
    exit();
}



#---------------------------------------------------------------------
# 

sub deletePod() {
    my ($pod_id) = @_;

    # check to make sure that the directory actually exists
    my $pod_path = "$labdir/pods/$pod_id";
    if (! -d $pod_path) {
	print "ERROR: pod path ($pod_path) does not exist - pod not deleted\n";
	exit;
    }

    # XXX - reclaim the app_ids pior to killing the directory structure

    opendir(POD_DIR, "$pod_path");
    my @files = readdir(POD_DIR);
    foreach $file (@files) {
	unlink "$pod_path/$file";
    }
    closedir(POD_DIR);
    rmdir("$pod_path");

    # create the log entry for the pod creation in the pod_dir
    open(ACTION_LOG, ">>$labdir/logs/lab-$opts{action}-log-$now_string.log\n") ||
	die "error opening log: $labdir/logs/lab-$opts{action}-log-$now_string.log\n";
    print ACTION_LOG "   deleted pod id: $pod_id\n";
    print ACTION_LOG " deleted pod path: $pod_path\n";
    print ACTION_LOG "-" x 70 . "\n\n";
    close(ACTION_LOG);

    return();
}



#---------------------------------------------------------------------
# pod startup
# 
sub batchStart() {
    my $pod_path = "$labdir/pods";

    opendir(POD_DIR, "$pod_path");
    my @pods = grep { !/^\.{1,2}$/ } readdir (POD_DIR);
    foreach $pod_id (@pods) {
	next if $pod =~ /^\./;	
	print "starting pod: $pod_id\n";
	&startPod($pod_id);
    }
    closedir(POD_DIR);

    return;
}


sub startPod() {
    my ($pod_id) = @_;

    # XXX - startup script return codes
    # an interesting question to ask is whether it makes sense to have the
    # startup scripts provide a nice return code which would provide a
    # good way for us to do this more robustly

    my $pod_path = "$labdir/pods/$pod_id";
    system "$pod_path/startup"; # || die "error starting pod: $?\n";
    return;
}



#---------------------------------------------------------------------
# pod stop
# 
sub batchStop() {
    my $pod_path = "$labdir/pods";

    opendir(POD_DIR, "$pod_path");
    my @pods = grep { !/^\.{1,2}$/ } readdir (POD_DIR);
    foreach $pod_id (@pods) {
	next if $pod =~ /^\./;	
	print "stopping pod: $pod_id\n";
	&stopPod($pod_id);
    }
    closedir(POD_DIR);
}

sub stopPod() {
    my ($pod_id) = @_;

    my $pod_path = "$labdir/pods/$pod_id";
    my @kill_pids = &parseWrapperLogFiles($pod_path);

    print "stopping processes in pod: $pod_id\n";
    foreach $pid (@kill_pids) {	print "$pid, "; }
    print "\n";

    kill 15, @kill_pids,
    return;
}


sub parseWrapperLogFiles() {
    my ($pod_path) = @_;

    my @pid_list = "";

    opendir(POD_DIR, "$pod_path");
    my @startup_logs = grep { /^.startlog/ } readdir (POD_DIR);
    foreach my $startlog (@startup_logs) {
	open(STARTLOG, "<<$pod_path/$startlog") || 
	    die "error opening: $pod_path/$startlog\n";
	while(<STARTLOG>) {
	    ($child, $parent) = /Process Id for child is (\d+), parent is (\d+)/;
	    # XXX do we just want to kill the parent process id?
	    push @pid_list, $child, $parent;
	}
	closedir(STARTLOG);
    }

    return @pid_list;
}


#---------------------------------------------------------------------
# pod initialization
# 
sub batchInit() {
    my ($pod_id, $template, $port_start, $batch) = @_;

    my $last_port = $port_start;

    for ($i = 1; $i <= $batch; $i++) {
	$start_port = $last_port;
	$last_port = &initPod($pod_id, $template, $start_port);
	print "pod_id: $pod_id - start port: $start_port - end port: $last_port\n";
	$pod_id++;    # increment the pod_id
	$last_port++; # increment this for the next initPod() run
    }
}


#---------------------------------------------------------------------
# Setup the pod for the student. which entails making the directory,
# parsing the template and unpacking the baseline configuration tarball as
# well as processing the NETMAP file and making the appropriate app_id
# allocations.
# 
sub initPod() {
  my ($pod_id, $template, $port_start) = @_;

  # load the template and populate the associated hash data structure
  my %template_vars = &parseTemplate($template);

  # sanity check template before we go any further
  &checkTemplate(%template_vars); 

  # make the directory for the pod under the instructors lab_dir
  # which is under the $labdir
  my $pod_path = "$labdir/pods/$pod_id";
  mkpath($pod_path, 0, 0755);	

  #-----------------------------------------------------------------
  # process the important template vars
  #
  my $iou_image_src = "$iou_base/$template_vars{iou_image}";
  my $iou_image_dst = "$pod_path/iou-image";
  # symlink to the image to be used in the lab
  symlink($iou_image_src, $iou_image_dst); 

  # symlink to the wrapper
  symlink($wrapper_src, "$pod_path/wrapper-$ENV{USER}-$pod_id"); 

  # tar the baseline configurations
  chdir($pod_path) || 
      die "can't change directory to $pod_path\n";

  # note: there might be some platform specific sensitivites related to
  # the use of the system and tar command.  one would think this would
  # just work, but ...
  system "$bin_tar xf $template_vars{base_config_arch}" || 
      die "error: tar failed ... $? - $!";

  chdir($cwd) || die "can't change directory to $cwd\n";

  # process the startup script and write it to the pod_path
  my ($port_end, $startup_script) = 
    &parseStartupTemplate($template_vars{startup_tmplt}, $port_start);

  my %startup_vars = (
		      'IMAGE'    => "iou-image",
		      'WRAPPER'  => "wrapper-$ENV{USER}-$pod_id",
		      'POD_PATH' => "$pod_path",
		      'IOURC'    => "$iourc",
		     );

  $startup_script = &filterVars($startup_script, %startup_vars);

  # netmap processing
  my ($open_ids, $resv_ids) = &loadAppIDs($appid_db); 
  my ($netmap_i, $rtrs)     = &parseNetmapTemplate($template_vars{netmap_tmplt});
     ($rtrs)                = &matchRtrIDs($rtrs, $open_ids, $resv_ids);
  &flushAppIDs($open_ids, $resv_ids, $appid_db);

  my $netmap_o = &parseOutputNetmap($netmap_i, $rtrs);
  &writeNETMAP($pod_path, $netmap_o);


  # process the startup script to make sure that we handle the router_ids
  # associated with it
  $startup_script = &parseOutputNetmap($startup_script, $rtrs);

  &renameNvramFiles($pod_path, $rtrs);

  # write the startup script to the pod_directory
  open(STARTUP, ">$pod_path/startup") || 
      die "error opening: $pod_path/startup for writing";
  print STARTUP "$startup_script\n";
  close(STARTUP);
  chmod(0755, "$pod_path/startup");

  # create the log entry for the pod creation in the pod_dir
  open(ACTION_LOG, ">>$labdir/logs/lab-$opts{action}-log-$now_string.log\n") ||
      die "error opening log: $labdir/logs/lab-$opts{action}-log-$now_string.log\n";
  print ACTION_LOG "       pod id: $pod_id\n";
  print ACTION_LOG "starting port: $port_start\n";
  print ACTION_LOG "  ending port: $port_end\n";
  print ACTION_LOG "     pod path: $pod_path\n";

  foreach my $k (sort keys %$rtrs) {
      print ACTION_LOG " template rtr_id: $k - pod rtr_id: " . $rtrs->{$k} . "\n";
  }

  print ACTION_LOG "-" x 70 . "\n\n";
  close(ACTION_LOG);

  return $port_end;
}


#---------------------------------------------------------------------
# utility functions
#
sub writeNETMAP() {
    my ($pod_path, $netmap) = @_;

    open(NETMAP_O, ">$pod_path/NETMAP") 
	|| die "error opening: $pod_path/NETMAP";
    print NETMAP_O "$netmap\n"; 
    close(NETMAP);
}

sub renameNvramFiles() {
    my ($pod_path, $rtrs) = @_;

    opendir(POD_DIR, "$pod_path");
    my @nvram_files = grep { /^nvram_/ } readdir (POD_DIR);
    foreach my $nvram (@nvram_files) {
	$_ = $nvram;
	($l_zero, $rtr_id) = /nvram_(0{1,})(\d+)/;
	#($rtr_id) = /nvram_(\d+)/;
	my $i_nvram = $nvram;
	my $zeropad = 5 - length($rtrs->{$rtr_id});
	my $o_nvram = "nvram_" . '0' x $zeropad . $rtrs->{$rtr_id};
	print "template nvram: $i_nvram pod nvram file: $o_nvram\n" if $debug >= 1;
	rename ("$pod_path/$i_nvram", "$pod_path/$o_nvram");
    }
    closedir(POD_DIR);

    return;
}

sub parseStartupTemplate() {
    my ($script_template, $port_start) = @_;

    my $startup_script = "";
    my $wrapper_port = $port_start;
    
    open(SCRIPT, "<$script_template") || 
	die "error opening script template for parsing: $script_template\n";

    while (<SCRIPT>) {
	if (/\%\%PORT\%\%/) {
	    $_ =~ s/\%\%PORT\%\%/$wrapper_port/g;
	    $wrapper_port++;
	}
	$startup_script .= $_;
    }
    my @startup_info = ($wrapper_port, $startup_script);
    return @startup_info;
}

#---------------------------------------------------------------------
# given a template and the global variables that we have access too,
# populate the data structure associated with this particular session
#
sub parseTemplate() {
    my ($template_path) = @_;

    my %template_vars = ();

    open(TEMPLATE, "<$template_path") || die "error opening: $template_path\n";
    while (<TEMPLATE>) {
	s/#.*//;            # ignore comments by erasing them
        next if /^(\s)*$/;  # skip blank lines
	chomp;              # whack the trailing newline
	my ($key, $value) = split(/=/, $_);
	$template_vars{$key} = $value;
    }
    close(TEMPLATE);
    return %template_vars;
}


sub checkTemplate {
  my %template_vars = @_;

  # make sure that we defined some of the critical template variables,
  # this is more of a sanity check than anything else.
  if (! defined($template_vars{iou_image}) ) {
    die "template processing error - no iou_image defined";
  } elsif (! defined($template_vars{startup_tmplt}) ) {
    die "template processing error - no startup_script defined";
  } elsif (! defined($template_vars{base_config_arch}) ) {
    die "template processing error - no base_config_arch defined";
  } elsif (! defined($template_vars{netmap_tmplt}) ) {
    die "template processing error - no netmap_template defined";
  }

  return;
}

sub printUsage() {
  print <<EOF;

for more information on the operation of this script check out the wiki
topic found here.

  http://twiki.cisco.com/Teams/WEP/TelcoEng/IouLabManager

EOF
  return;	
	
}



sub flushAppIDs {
    my ($open_ids, $resv_ids, $appid_db) = @_;

    open (APPID_DB, ">$appid_db") || die "error: unable to open $appid_db";

    foreach my $i (@$open_ids) { print APPID_DB "$i\:OPEN\n"; }
    foreach my $j (@$resv_ids) { print APPID_DB "$j\:RESV\n"; }

    close(APPID_DB);
}

# given a hash of router id's from the netmap template, let's match these
# up with an available app_id from the open app_ids hash - then perform
# the required push/shift on the available app_id structures

sub matchRtrIDs {
    my ($rtr_list, $open_ids, $resv_ids) = @_;

    foreach $rtr (keys (%$rtr_list)) {
	my $appid = shift @$open_ids;
	$rtr_list->{$rtr} = $appid;
	push @$resv_ids, $appid;
    }

    return $rtr_list;

} 

# if we're initializing the workspace we need to generate the list of
# app-id's and write it to file
sub initAppIdDb() {
    my ($appid_db) = @_;

    print "no appid_db - creating one ...";
    open (APPID_DB, ">$appid_db") || die "error: unable to open $appid_db";
    foreach $i (1 .. 999) { 
	print APPID_DB "$i\:OPEN\n" 
    }
    close(APPID_DB);
    print " done\n";
    
    return;
}

sub loadAppIDs() {
    my ($appid_db) = @_;
    
    my @resv_appid = ();  # reserved app_ids
    my @open_appid = ();  # open app_ids
    
    open(APPID_DB, "$appid_db") || die "error opening app_id db: $appid_db";
    while(<APPID_DB>) { # 
	my ($id, $state) = split(/:/, $_);
	if ($state eq "RESV") {
	    push @resv_appid, $id;
	} else { # available
	    push @open_appid, $id;
	}
    }
    close(APPID_DB);

    return(\@open_appid, \@resv_appid, );
}


# we're going to have to parse the router id info more intelligently.
# when we run across the %%RTR_###%% in the netmap template we can replace
# this with the appropriate entry from the appid_db
sub parseNetmapTemplate() {
    my ($template) = @_;

    my %rtrs = ();

    open(NETMAP_T, "$template") 
	|| die "error opening: $template";
    while (<NETMAP_T>) { 
	my (@rtr_ids) = /\%\%(\d+)\%\%/g;

	# there has to be a better way to do this, but right now it will do the trick
	foreach my $rtr_id (@rtr_ids) {
	    if (!defined $rtrs{$rtr_id}) {
		$rtrs{$rtr_id} = "x";
	    }
	}
	$netmap .= $_; 
    }
    close(NETMAP_T);

    return($netmap, \%rtrs);
}


#-----------------------------------------------------------
# filterVars(Buffer, HashwRepVars)
sub filterVars {
  my ($FilterStream, %SearchVars)   = @_;
  
  $FilterStream =~ s/\%\%([a-zA-Z0-9_]+)\%\%/
    my $Value = $SearchVars{$1};
  if (!defined $Value) {
    $Value = "\%\%$1\%\%"; # leave it as is
  }
  $Value;
  /ge;
  return $FilterStream;
}

sub parseOutputNetmap() {
  my ($netmap, $rtrs)   = @_;
  
  $netmap =~ s/\%\%([0-9]+)\%\%/
    my $value = $rtrs->{$1};
  if (!defined $value) {
    print STDERR "$value - not found\n";
  }
  $value;
  /ge;

  return $netmap;

}
