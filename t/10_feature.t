use strict;
use warnings;
use Test::Tester; # Call before any other Test::Builder-based modules
use Test::More;
use Test::Deep qw( cmp_deeply methods );
use parent qw( Test::Class );

use Plack::Request;
use Test::WWW::Stub;
use LWP::UserAgent;

sub ua { LWP::UserAgent->new; }

sub test_pass {
    my ($sub) = shift;
    my ($premature, @results) = run_tests( $sub );
    return $results[0]->{ok};
}

sub register : Tests {
    my $self = shift;

    subtest 'register string uri and arrayref res' => sub {
        {
            my $g = Test::WWW::Stub->register(q<http://example.com/TEST/>,  [ 200, [], [ '1' ] ]);

            my $res = $self->ua->get('http://example.com/TEST/');
            ok $res->is_success;
            is $res->content, '1';

            ok $self->ua->get('http://example.com/TEST')->is_error, 'match only with exact same uri';
        }

        ok $self->ua->get('http://example.com/TEST/')->is_error, 'error outside guard';
    };

    subtest 'register regex uri and arrayref res' => sub {
        my $g = Test::WWW::Stub->register(qr<\A\Qhttp://example.com/MATCH/\E>,  [ 200, [], [ '1' ] ]);

        my $res = $self->ua->get('http://example.com/MATCH/hoge');
        ok $res->is_success, 'match according to regexp';
        is $res->content, '1';

        ok $self->ua->get('http://example.com/NONMATCH/hoge')->is_error;
    };

    subtest 'register string uri and PSGI app' => sub {
        my $app = sub {
            my $env = shift;
            my $req = Plack::Request->new($env);
            my $headers = [
                'X-Test-Req-Uri' => $req->uri,
            ];
            return [ 200, $headers, [ 1 ] ];
        };
        my $g = Test::WWW::Stub->register(q<http://example.com/TEST> => $app);

        my $res = $self->ua->get('http://example.com/TEST');
        ok $res->is_success;
        is $res->header( 'X-Test-Req-Uri' ), 'http://example.com/TEST', 'app receives proper env';
    };

    subtest 'register without guard ' => sub {
        {
            Test::WWW::Stub->register(q<http://example.com/HOGE/>,  [ 200, [], [ '1' ] ]);
            ok $self->ua->get('http://example.com/HOGE/')->is_success, 'stub works when registered without guard';
        }

        ok $self->ua->get('http://example.com/HOGE/')->is_success, 'when registered without guard, stub works outside of scope too.';
    };

}

sub unstub : Tests {
    my $self = shift;

    my $stub_g = Test::WWW::Stub->register('http://example.com/TEST', [ 200, [], ['2'] ]);
    ok $self->ua->get('http://example.com/TEST')->is_success;

    {
        my $unstub_g = Test::WWW::Stub->unstub;
        ok $self->ua->get('http://example.com/TEST')->is_error, 'unstubbed';
    }

    ok $self->ua->get('http://example.com/TEST')->is_success, 're-registered stub';

    subtest 'unstub again' => sub {
        {
            my $unstub_g = Test::WWW::Stub->unstub;
            ok $self->ua->get('http://example.com/TEST')->is_error, 'unstubbed';
        }

        ok $self->ua->get('http://example.com/TEST')->is_success, 're-registered stub';
    }
}

sub request : Tests {
    my $self = shift;

    my $stub_g = Test::WWW::Stub->register(qr<\A\Qhttp://request.example.com/\E>, [ 200, [], ['okok'] ]);

    $self->ua->get('http://request.example.com/FIRST');
    $self->ua->get('http://request.example.com/SECOND');

    ok test_pass(
        sub{ Test::WWW::Stub->requested_ok('GET', 'http://request.example.com/FIRST') }
    ), 'passes when calling with requested method-uri pair';

    ok ! test_pass(
        sub{ Test::WWW::Stub->requested_ok('GET', 'http://request.example.com/NOTREQUESTED') }
    ), 'fails when calling with not-requested uri';

    ok ! test_pass(
        sub{ Test::WWW::Stub->requested_ok('POST', 'http://request.example.com/FIRST') }
    ), 'We requested only by GET, so requeted_ok("POST", ..) fails';

    subtest 'last_request' => sub {
        ok my $last_req = Test::WWW::Stub->last_request;
        is $last_req->method, 'GET';
        is $last_req->uri, 'http://request.example.com/SECOND';
    };
}

__PACKAGE__->runtests;
