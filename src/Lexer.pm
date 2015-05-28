package Plex::Lexer;

use Tie::IxHash;
use Perl6::Slurp;
use YAML::Tiny;

my (%tokens, $slurp);
my $i = 0;

my $yaml = YAML::Tiny->new();
$yaml = YAML::Tiny->read( '/etc/plex/lex.cfg' );
$yaml = $yaml->[0];

my $yaml2 = YAML::Tiny->new();
$yaml2 = YAML::Tiny->read( '/etc/plex/plex.cfg' );
$yaml2 = $yaml2->[0];

my $chars = $yaml2->{compiler}->{ignore_chars};
print "Chars: $chars\n";
my $ty = tie(%tokens, Tie::IxHash);

sub new {
    my $class = shift;
    my $self  = {};
    bless ($self, $class);
    return $self;
}

sub read_file {
    my ($self, $file) = @_;
    $slurp = slurp($file);
    return 1;
}

sub read {
    my ($self, $string) = @_;
    $slurp = $string;
    return 1;
}

sub lex {
    my $self = shift;
    while (1) {
        last if $slurp =~ m/\G\z/;
        foreach my $rule (keys %{$yaml}) {
            if ($slurp =~ m/ \G $yaml->{$rule}->{start}(.+?)$yaml->{$rule}->{end} /sgcx) {
                $tokens{$i} = { token => $1, object => $rule };
                $i++;
            }
        }
        match_text() or
        die "Syntax error!";
    }
    %{$self->{tokens}} = %tokens;
    return $self;
}

sub match_text {
    if ($slurp =~ m/ \G (.+?) (?= <\/?[$chars] | \z) /sgcx) {
        $tokens{$i} = { token => $1, object => "TEXT" };
        $i++;
        return 1;
    }
    return 0;
}

1;
