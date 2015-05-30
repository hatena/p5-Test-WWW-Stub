package Test::WWW::Stub::Feature::Fixture;
use 5.010;
use strict;
use warnings;

our $VERSION = "0.02";

# Same as Test::WWW::Stub
use Carp ();
use Plack::Request;
use Test::More ();
use URI;
# Feature specific
use LWP::UserAgent;
use HTTP::Request;
use Path::Class qw(dir);
use Plack::Response;

use Class::Accessor::Lite (
    ro  => [qw/cache_dir ua_class/],
    new => 1,
);

sub initialize {
    my ($class, %args) = @_;

    $args{cache_dir} //= 't/fixtures/webmock';
    my $instance = $class->new(%args);

    $instance->{_fallback_guard} = Test::WWW::Stub->_register_fallback( sub {
        $instance->process_request(shift);
    } );
}

sub cache_dir_dir {
    my $self = shift;
    $self->{_cache_dir_dir} //= dir($self->cache_dir);
}

sub create_ua {
    my $self = shift;
    $self->{ua_class} ? $self->{ua_class}->new : LWP::UserAgent->new;
}

sub cache_file_for_uri {
    my ($self, $uri) = @_;
    $self->cache_dir_dir->file(URI::Escape::uri_escape_utf8($uri));
}

sub process_request {
    my ($self, $env) = @_;
    my $req = Plack::Request->new($env);

    my $cache_file = $self->cache_file_for_uri($req->uri);

    # from local file
    if (-f $cache_file) {
        my $raw_res = $cache_file->slurp;
        my $http_res = HTTP::Response->parse($raw_res);
        my $plack_res = Plack::Response->new($http_res->code, $http_res->headers, $http_res->content);
        return $plack_res->finalize;
    }

    # capture from remote if specified in ENV
    if ($ENV{WWW_STUB_ENABLE_CAPTURE}) {
        my ($file, $line) = Test::WWW::Stub::_trace_file_and_line();

        my $uri = $req->uri->clone;
           $uri->path_query($uri->path);

        my $method = $req->method;

        Test::More::diag "Capturing external access: $method $uri at $file line $line.";
        my $cache_dir = $self->cache_dir_dir;
        unless (-d $cache_dir) {
            $cache_dir->mkpath;
        }
        my $http_req = HTTP::Request->new($req->method, $req->uri, $req->headers, $req->content);

        my $res = do {
            my $undef_guard = Test::WWW::Stub->unstub;

            $self->create_ua->request($http_req);
        };

        my $writer = $cache_file->openw;
        $writer->print($res->as_string);
        $writer->close;

        my $plack_res = Plack::Response->new($res->code, $res->headers, $res->content);
        return $plack_res->finalize;
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Test::WWW::Stub::Feature::Fixture - Pre-captured response from fixture file

=head1 SYNOPSIS

    use Test::WWW::Stub ( fixture => 1 );

=head1 DESCRIPTION

TBD

=head1 LICENSE

Copyright (C) Hatena Co., Ltd.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Asato Wakisaka E<lt>asato.wakisaka@gmail.comE<gt>

Original implementation written by hitode909.

=cut
