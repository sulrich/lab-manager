#!/opt/local/bin/perl

my $appid_db = "$ENV{HOME}/.app_id";
my $netmap   = "$ENV{HOME}/Desktop/telco-iou/NETMAP";


if (! -e $appid_db) { &initAppIdDb($appid_db); }

($open_ids, $resv_ids) = &loadAppIDs($appid_db); 
($netmap_i, $rtrs)     = &parseNetmapTemplate($netmap);
($rtrs)                = &matchRtrIDs($rtrs, $open_ids, $resv_ids);


&flushAppIDs($open_ids, $resv_ids, $appid_db);

foreach my $l (keys %$rtrs) {
    print "$l => " . $rtrs->{$l} . "\n";
}

my $output_netmap = &parseOutputNetmap($netmap_i, $rtrs);


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

sub flushAppIDs {
    my ($open_ids, $resv_ids, $appid_db) = @_;

    print "flushing appid_db to disk ...";
    open (APPID_DB, ">$appid_db") || die "error: unable to open $appid_db";

    foreach my $i (@$open_ids) { print APPID_DB "$i\:OPEN\n"; }
    foreach my $j (@$resv_ids) { print APPID_DB "$j\:RESV\n"; }

    close(APPID_DB);
    print " done\n";
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


sub parseNETMAP() {
    my ($pod_path, $nmap_pref) = @_;
    my $netmap = "";
    
    my %vars = ('NMAP_PREF' => $nmap_pref);
    open(NETMAP_I, "$pod_path/NETMAP") 
	|| die "error opening: $pod_path/NETMAP";
    while (<NETMAP_I>) { $netmap .= $_; }
    close(NETMAP_I);

    $netmap = &filterVars($netmap, %vars);

    open(NETMAP_O, ">$pod_path/NETMAP") 
	|| die "error opening: $pod_path/NETMAP";
    print NETMAP_O "$netmap\n"; 
    close(NETMAP);
}
