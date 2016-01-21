package Test::WWW::Stub::Handler;

use strict;
use warnings;

use Carp qw(confess);

sub new {
    my ($class, %args) = @_;
    my $pattern = $args{pattern};
    my $app     = $args{app};
    return bless { pattern => $pattern, app => $app }, $class;
}

sub factory {
    my ($class, $uri_or_re, $app_or_res) = @_;
    my $app;
    my $type = ref($app_or_res);
    if ($type eq 'CODE') {
        $app = $app_or_res;
    } elsif ($type eq 'ARRAY') {
        $app = sub { $app_or_res };
    } else {
        confess 'Handler MUST be a PSGI app or an ARRAY';
    }
    return $class->new(pattern => $uri_or_re, app => $app);
}

sub is_regexp {
    my ($self) = @_;
    return ref($self->{pattern}) eq 'Regexp';
}

sub is_str {
    my ($self) = @_;
    return ! $self->is_regexp;
}

sub try_call {
    my ($self, $uri, $env, $req) = @_;
    my ($matched, $captures) = $self->_match($uri);
    return undef unless $matched;
    return $self->_call($env, $req, @$captures);
}

sub _call {
    my ($self, $env, $req, @match) = @_;
    $env->{'test.www.stub.handler'} = [ $self->{pattern}, $self->{app} ];
    return $self->{app}->($env, $req, @match);
}

sub _match {
    my ($self, $uri) = @_;
    return $self->is_str ? $self->_match_str($uri) : $self->_match_regexp($uri);
}

sub _match_str {
    my ($self, $uri) = @_;
    my $matched = $uri eq $self->{pattern} ? 1 : 0;
    return ($matched, []);
}

sub _match_regexp {
    my ($self, $uri) = @_;
    my $pattern = $self->{pattern};
    my @captures = $uri =~ m/$pattern/;
    my $matched = @captures > 0 ? 1 : 0;
    return ($matched, \@captures);
}

1;
