package Plex::Log;

use YAML::Tiny;
my $yaml = YAML::Tiny->new();
$yaml = YAML::Tiny->read( '/etc/plex/plex.cfg' );
$yaml = $yaml->[0];

my %codes = (
    0   =>  LOG2,
    1   =>  LOG1,
    2   =>  LOG3,
);

sub new {
    my $package = shift;
    if (-d $yaml->{log}->{dir}) {
        if (!(-e $yaml->{log}->{dir}."/".$yaml->{log}->{access}) || (-e $yaml->{log}->{dir}."/".$yaml->{log}->{error}) || (-e $yaml->{log}->{dir}."/".$yaml->{log}->{status})) {
            open(ACCESS, ">".$yaml->{log}->{access});
            &inner(ACCESS, "Created Logfile.");
            close(ACCESS);
            open(ERROR, ">".$yaml->{log}->{error});
            &inner(ERROR, "Created Logfile.");
            close(ERROR);
            open(STATUS, ">".$yaml->{log}->{access});
            &inner(STATUS, "Created Logfile.");
            close(STATUS);
        }
    } else {
        `mkdir $yaml->{log}->{dir}`;
    }
    my $self = {};
    $self->{access} = $yaml->{log}->{access};
    $self->{error}  = $yaml->{log}->{error};
    $self->{status} = $yaml->{log}->{status};
    $self->{dir}    = $yaml->{log}->{dir};
    bless ($self, $package);
    return $self;
}

sub init {
    my $self = shift;
    open(LOG1, ">>".$self->{access});
    open(LOG0, ">>".$self->{error});
    open(LOG2, ">>".$self->{status});
}

sub log {
    my ($code, $message) = @_;
    &inner($code, $message);
}

sub inner {
    my ($code, $string) = (shift, shift);
    my $time = localtime();
    if ($code == 0) {
        print LOG0 "[$time] $string\n";
    } elsif ($code == 1) {
        print LOG1 "[$time] $string\n";
    } elsif ($code == 2) {
        print LOG2 "[$time] $string\n";
    }
    return 1;
}

1;
