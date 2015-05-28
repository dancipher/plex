package Handlers;

use lib '/';
use Plex::Compiler;
use Plex::Lexer;

local $/ = undef;
my $lex = Plex::Lexer->new();

sub html_handler {
    my (undef, $file) = @_;
    open(HTML, $file);
    my $retr = <HTML>;
    close (HTML);
    return $retr;
}

sub plex_handler {
    my (undef, $file, $c, $r) = @_;
    my %ARGS;
    $ARGS{'REMOTE_ADDR'}  = $c->peerhost if defined $c;
    $ARGS{'QUERY_STRING'} = $r->url->equery if defined $r;
    $lex->read_file( $file );
    $lex->lex();
    my $comp = Plex::Compiler->new(%{$lex->{tokens}}, %ARGS);
    $comp->compile();
    $comp->execute();
    return $comp->{out};
}

sub image_handler {
    my (undef, $file) = @_;
    open(IMAGE, $file);
    my $retr = <IMAGE>;
    close (IMAGE);
    return $retr;
}

sub js_handler {
    my (undef, $file) = @_;
    open(JS, $file);
    my $retr = <JS>;
    close (JS);
    return $retr;
}

sub flash_handler {
    my (undef, $file) = @_;
    open(FLASH, $file);
    my $retr = <FLASH>;
    close (FLASH);
    return $retr;
}

1;
