package Test::WWW::Stub::HandlerRegistry;

use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless { registry => {} }, $class;
}

sub keys : method {
    my ($self) = @_;
    return [ keys %{ $self->{registry} } ];
}

sub get {
    my ($self, $key) = @_;
    return $self->{registry}->{$key};
}

sub register {
    my ($self, $uri_or_re, $app_or_res) = @_;
    my $handler = {
        type => (ref $uri_or_re || 'Str'),
        (ref $app_or_res eq 'CODE'
            ? ( app => $app_or_res )
                : ( res => $app_or_res )),
    };
    $self->{registry}->{$uri_or_re} = $handler;
}

sub unregister {
    my ($self, $uri_or_re) = @_;
    delete $self->{registry}->{$uri_or_re} if exists $self->{registry}->{$uri_or_re};
}

1;
