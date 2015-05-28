use lib '/';

use Handlers;
use Plex::Daemon;
use Plex::Log;
use YAML::Tiny;
use POSIX;

my $cfg     = $ARGV[0] || '/etc/plex/plex.cfg';
my (%children, $children);

my $yaml    = YAML::Tiny->new();
$yaml       = YAML::Tiny->read( $cfg );
$yaml       = $yaml->[0];

opendir(VHOSTS, $yaml->{common}->{document_root});
my @vhosts = readdir(VHOSTS);
close(VHOSTS);

my $log    = Plex::Log->new();

my $http = Plex::Daemon->new( LocalPort => $yaml->{port}->{http} ) or $log->log(0,"Couldn't setup sock: $!");
if ($http) {
    $log->log(2,"Server Sock $http is there.");
    print "Plex Webserver is booted.\n";
}
&daemonize;
&spawn_children;
&keep_ticking;

sub spawn {
    my $pid;
    my $sigset = POSIX::SigSet->new(SIGINT);
    sigprocmask(SIG_BLOCK, $sigset) or die "Can't block SIGINT for fork: $!";
    die "Cannot fork child: $!\n" unless defined ($pid = fork);
    if ($pid) {
        $children{$pid} = 1;
        $children++;
        warn "forked new child, we now habe $children children";
        return;
    }
    my $i = 0;
    while ($i < $yaml->{child}->{lifetime}) {
        $i++;
        my $client = $http->accept or last;
        $client->autoflush(1);
        log_message("[CLIENT] ".$client->peerhost."\n");
        my $request = $client->get_request(1) or last;
        my $url     = $request->url->path;
        my $host    = $request->header('Host');
        my $found = 0;
        foreach my $vhost (@vhosts) {
            if ($host eq $vhost) {
                $found = 1;
            } 
        }
        if ($found == 0) {
            $host = "";
        }
        my $yep     = $yaml->{common}->{document_root}."/$host/".$url;
        if (-d $yep) {
            opendir(DIR, $yep);
            my @files_in_dir = readdir(DIR);
            closedir(DIR);
            foreach my $file_in_dir (@files_in_dir) {
                if ($file_in_dir =~ /index\.(.*)/i) {
                    my $is_suffix = $1;
                    foreach my $obj (keys %{$yaml->{filetype}}) {
                        foreach my $suffix (@{$yaml->{filetype}->{$obj}->{suffix}}) {
                            if ($is_suffix eq $suffix) {
                                my $handler = $yaml->{filetype}->{$obj}->{handler};
                                my $retr = Handlers->$handler($yaml->{common}->{document_root}."/$host/index.".$is_suffix, $client, $request);
                                my $req = HTTP::Response->new(200);
                                $req->header("Content-Type",$yaml->{filetype}->{$obj}->{filetype}, "Server", "Plex2");
                                $req->content( $retr);
                                $client->send_response($req);
                                exit;
                            }
                        }
                    }
                }
            }
        } elsif (-e $yep) {
            if ($yep =~ /\/(.*?)\.(.*)/) {
                my $is_suffix = $2;
                foreach my $obj (keys %{$yaml->{filetype}}) {
                    foreach my $suffix (@{$yaml->{filetype}->{$obj}->{suffix}}) {
                        if ($is_suffix eq $suffix) {
                            my $handler = $yaml->{filetype}->{$obj}->{handler};
                            my $retr = Handlers->$handler($yep, $client, $request);
                            my $req = HTTP::Response->new(200);
                            $req->header("Content-Type",$yaml->{filetype}->{$obj}->{filetype}, "Server", "Plex2");
                            $req->content( $retr );
                            $client->send_response( $req );
                            $log->log(1, "[200] Delivered File ".$request->url->path);
                            exit;
                        }
                    }
                }
            }
        } else {
           my $req = HTTP::Response->new(404);
           $req->header("Content-Type","text/html","Server","Plex2");
           $req->content("No such file or directory.");
           $client->send_response( $req );
           $log->log(1, "[404] Couldn't find ".$request->url->path);
        }
        $client->close;
    }
    warn "child terminated after $i requests";
    exit;
}

sub keep_ticking {
    while (1) {
        for (my $i = $children; $i < $yaml->{child}->{total}; $i++) {
            &spawn;
        }
    };
}

sub spawn_children {
    for (1..$yaml->{child}->{total}) {
        &spawn;
    }
}

sub reaper {
    my $stiff;
    while (($stiff = waitpid(-1, &WHOHANG)) > 0) {
        warn("child $stiff terminated -- status $?");
        $children--;
        delete $children{$stiff};
    }
    $SIG{CHLD} = \&reaper;
}

sub daemonize {
    my $pid = fork;
    defined ($pid) or die "Cannot start daemon: $!";
    print "Parent Daemon running.\n" if $pid;
    exit if $pid;
    POSIX::setsid();
    close (STDOUT);
    close (STDIN);
    close (STDERR);
    $SIG{__WARN__} = sub {
        &log_message("NOTE! " . join(" ", @_));
    };
    $SIG{__DIE__} = sub {
        &log_message("FATAL! " . join(" ", @_));
        exit;
    };
    $SIG{HUP} = $SIG{INT} = $SIG{TERM} = sub {
        my $sig = shift;
        $SIG{$sig} = 'IGNORE';
        kill 'INT' => keys %children;
        die "killed by $sig\n";
        exit;
    };
    $SIG{CHLD} = \&reaper;
}

sub log_message {
    my $text = shift;
    open(LOG, ">>".$y->{common}->{logfile});
    print LOG "$text\n";
    close (LOG);
}
