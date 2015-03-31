# NAME

Test::WWW::Stub - Stub specified URL for LWP

# SYNOPSIS

    use Test::WWW::Stub;

    my $ua = LWP::UserAgent->new;

    my $stubbed_res = [ 200, [], ['okay'] ];
    Test::WWW::Stub->register(q<http://example.com/TEST/>, $stubbed_res);

    is $ua->get('http://example.com/TEST')->content, 'okay';

    # You can also use regexp for uri
    Test::WWW::Stub->register(qr<\A\Qhttp://example.com/MATCH/\E>, $stubbed_res);

    is $ua->get('http://example.com/MATCH/hogehoge')->content, 'okay';

    my $last_req = Test::WWW::Stub->last_request; # Plack::Request
    is $last_req->uri, 'http://example.com/MATCH/hogehoge';

    Test::WWW::Stub->requested_ok('GET', 'http://example.com/TEST'); # passes

# DESCRIPTION

Test::WWW::Stub is a helper module to stub some http(s) request in your test.

Because this modules uses [LWP::UserAgent::PSGI](https://metacpan.org/pod/LWP::UserAgent::PSGI) internally, you don't have to modify target codes using [LWP::UserAgent](https://metacpan.org/pod/LWP::UserAgent).

# METHODS

- `register`

        my $guard = Test::WWW::Stub->register( $uri_or_re, $app_or_res );

    Registers a new stub for URI `$uri_or_re`. `$uri_or_re` is either an URI string or a compiled regular expression for URI.

    `$app_or_res` is a PSGI response array ref, or code ref which returns a PSGI response array ref.

    Once registered, `$app_or_res` will be return from LWP::UserAgent on requesting certain URI matches `$uri_or_re`.

- `requested_ok`

        Test::WWW::Stub->requested_ok($method, $uri);

    Passes when `$uri` has been requested with `$method`, otherwise fails and dumps requests handled by Test::WWW::Stub.

    This method calls `Test::More::ok` or `Test::More::diag` internally.

- `requests`

        my @requests = Test::WWW::Stub->requests;

    Returns an array of [Plack::Request](https://metacpan.org/pod/Plack::Request) which is handled by Test::WWW::Stub.

- `last_request`

        my $last_req = Test::WWW::Stub->last_request;

    Returns a Plack::Request object last handled by Test::WWW::Stub.

    This method is same as `[Test::WWW::Stub->requests]->[-1]`.

# LICENSE

Copyright (C) Hatena Co., Ltd.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Asato Wakisaka <asato.wakisaka@gmail.com>

Original implementation written by suzak.
