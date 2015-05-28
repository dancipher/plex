package Plex::Compiler;

use YAML::Tiny;
use IO::Capture::Stdout;
my $yaml = YAML::Tiny->new();
$yaml = YAML::Tiny->read( '/etc/plex/comp.cfg' );
$yaml = $yaml->[0];
my $capture = IO::Capture::Stdout->new();

my @comp;
my $i = 0;

sub new {
    my ($class, %tokens) = @_;
    my $self = {};
    %{$self->{tokens}} = %tokens;
    bless ($self, $class);
    return $self;
}

sub compile {
    my $self = shift;
    my $foo;
    $i++ foreach (keys %{$self->{tokens}});
    $i--;
    for my $a (0..$i) {
        my $object = $self->{tokens}{$a}->{object};
        my $token = $self->{tokens}{$a}->{token};
        $foo = $yaml->{$object};
        $foo =~ s/\?/$token/;
        push(@comp, "$foo\n");
    }
    @{$self->{comp}} = @comp;
    return $self;
}

sub execute {
    my ($self, %ARGS) = @_;
    local %ENV = %ARGS if defined %ARGS;
    my $code = join('', @{$self->{comp}});
    $capture->start;
    eval($code);
    $capture->stop;
    my @all = $capture->read;
    my $all = join('', @all);
    $self->{out} = $all;
    return $self;
}

1;
