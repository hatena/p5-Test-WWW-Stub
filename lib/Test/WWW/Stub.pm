package Test::WWW::Stub;
use 5.010;
use strict;
use warnings;

our $VERSION = "0.02";

use Carp ();
use Guard;  # guard
use LWP::Protocol::PSGI;
use Plack::Request;
use Test::More ();
use List::MoreUtils ();
use URI;

our $Handlers = { };
our @Requests;

sub register {
    my ($class, $uri_or_re, $app_or_res) = @_;
    $app_or_res //= [200, [], []];
    my $old_handler = $Handlers->{$uri_or_re};

    $Handlers->{$uri_or_re} = {
        type => (ref $uri_or_re || 'Str'),
        (ref $app_or_res eq 'CODE'
            ? ( app => $app_or_res )
                : ( res => $app_or_res )),
    };
    defined wantarray && return guard {
        if ($old_handler) {
            $Handlers->{$uri_or_re} = $old_handler;
        } else {
            delete $Handlers->{$uri_or_re};
        }
    };
}

sub last_request {
    return undef unless @Requests;
    return $Requests[-1];
}

sub requests { @Requests }

sub requested_ok {
    my ($class, $method, $url) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    Test::More::ok(
        List::MoreUtils::any(sub {
            my $req_url = $_->uri->clone;
               $req_url->path_query($req_url->path);
            $_->method eq $method && $req_url eq $url
        }, @Requests),
        "stubbed $method $url",
    ) or Test::More::diag Test::More::explain [ map { $_->method . ' ' . $_->uri } @Requests ]
}

sub clear_requests {
    @Requests = ();
}

my $app = sub {
    my ($env) = @_;
    my $req = Plack::Request->new($env);

    push @Requests, $req;

    # Don't use query part of URI for handler matching.
    my $uri = $req->uri->clone;
       $uri->path_query($uri->path);

    for my $key (keys %$Handlers) {
        my $handler = $Handlers->{$key};
        my @match;
        if ($handler->{type} eq 'Regexp' ? (@match = ($uri =~ qr<$key>)) : $uri eq $key) {
            if (my $app = $handler->{app}) {
                $env->{'test.www.stub.handler'} = [ $key, $app ];
                my $res = $app->($env, $req, @match);
                return $res if $res;
            } elsif (my $res = $handler->{res}) {
                return $res;
            } else {
                Test::More::BAIL_OUT 'Handler MUST be a PSGI app or an ARRAY';
            }
        }
    }

    my $level = $Test::Builder::Level;
    my (undef, $file, $line) = caller($level);
    while ($file && $file !~ m<\.t$>) {
        (undef, $file, $line) = caller(++$level);
    }
    my $method = $req->method;
    Test::More::diag "Unexpected external access: $method $uri at $file line $line";

    return [ 499, [], [] ];
};

my $register_g = LWP::Protocol::PSGI->register($app);

sub unstub {
    Carp::croak 'guard is required' unless defined wantarray;
    undef $register_g;
    return guard {
        $register_g = LWP::Protocol::PSGI->register($app);
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Test::WWW::Stub - Block and stub specified URL for LWP

=head1 SYNOPSIS

    # External http(s) access via LWP is blocked by just using this module.
    use Test::WWW::Stub;

    my $ua = LWP::UserAgent->new;

    my $stubbed_res = [ 200, [], ['okay'] ];

    {
        my $guard = Test::WWW::Stub->register(q<http://example.com/TEST>, $stubbed_res);

        is $ua->get('http://example.com/TEST')->content, 'okay';
    }
    isnt $ua->get('http://example.com/TEST')->content, 'okay';

    {
        # registering in void context doesn't create guard.
        Test::WWW::Stub->register(q<http://example.com/HOGE/>, $stubbed_res);

        is $ua->get('http://example.com/HOGE')->content, 'okay';
    }
    is $ua->get('http://example.com/HOGE')->content, 'okay';

    {
        # You can also use regexp for uri
        my $guard = Test::WWW::Stub->register(qr<\A\Qhttp://example.com/MATCH/\E>, $stubbed_res);

        is $ua->get('http://example.com/MATCH/hogehoge')->content, 'okay';
    }

    {
        # you can unstub and allow external access temporary
        my $unregister_guard = Test::WWW::Stub->unregister;

        # External access occurs!!
        ok $ua->get('http://example.com');
    }

    my $last_req = Test::WWW::Stub->last_request; # Plack::Request
    is $last_req->uri, 'http://example.com/MATCH/hogehoge';

    Test::WWW::Stub->requested_ok('GET', 'http://example.com/TEST'); # passes


=head1 DESCRIPTION

Test::WWW::Stub is a helper module to block external http(s) request and stub some specific requests in your test.

Because this modules uses L<LWP::Protocol::PSGI> internally, you don't have to modify target codes using L<LWP::UserAgent>.

=head1 METHODS

=over 4

=item C<register>

    my $guard = Test::WWW::Stub->register( $uri_or_re, $app_or_res );

Registers a new stub for URI C<$uri_or_re>.
If called in void context, it simply registers the stub.
Otherwise,it returns a new guard which drops the stub on destroyed.

C<$uri_or_re> is either an URI string or a compiled regular expression for URI.
C<$app_or_res> is a PSGI response array ref, or a code ref which returns a PSGI response array ref.
If C<$app_or_res> is a code ref, requests are passed to the code ref following syntax:

    my $req = Plack::Request->new($env);
    $app_or_res->($env, $req);

Once registered, C<$app_or_res> will be return from LWP::UserAgent on requesting certain URI matches C<$uri_or_re>.

=item C<requested_ok>

    Test::WWW::Stub->requested_ok($method, $uri);

Passes when C<$uri> has been requested with C<$method>, otherwise fails and dumps requests handled by Test::WWW::Stub.

This method calls C<Test::More::ok> or C<Test::More::diag> internally.

=item C<requests>

    my @requests = Test::WWW::Stub->requests;

Returns an array of L<Plack::Request> which is handled by Test::WWW::Stub.

=item C<last_request>

    my $last_req = Test::WWW::Stub->last_request;

Returns a Plack::Request object last handled by Test::WWW::Stub.

This method is same as C<[Test::WWW::Stub-E<gt>requests]-E<gt>[-1]>.

=item C<clear_requests>

    Test::WWW::Stub->clear_requests;

Clears request history of Test::WWW::Stub.

C<[Test::WWW::Stub-E<gt>requests]> becomes empty just after this method called.

=item C<unstub>

    my $unstub_guard = Test::WWW::Stub->unstub;

Unregister stub and enables external access, and returns a guard object which re-enables stub on destroyed.

In constrast to C<register>, this method doesn't work when called in void context.

=back

=head1 LICENSE

Copyright (C) Hatena Co., Ltd.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Asato Wakisaka E<lt>asato.wakisaka@gmail.comE<gt>

Original implementation written by suzak.

=cut

