use strict;
use warnings;
use Test::More;
use parent qw(Test::Class);

use File::Temp qw(tempdir);
use Guard qw(guard);
use LWP::UserAgent;
use Path::Class qw(file);

use Test::WWW::Stub::Feature::Fixture;

sub ua { LWP::UserAgent->new; }

## Test behaviour about UA of Feature::Fixture directly
my $default = Test::WWW::Stub::Feature::Fixture->new;
Test::More::isa_ok $default->create_ua, 'LWP::UserAgent', 'default UA';

my $specified = Test::WWW::Stub::Feature::Fixture->new( ua_class => 'Test::WWW::Stub::UserAgent' );
Test::More::isa_ok $specified->create_ua, 'LWP::UserAgent', 'default UA';


## Test other behaviours via Test::WWW::Stub

# copy prepared fixture to tempdir
my $mock_directory = tempdir;
my $mock_file = file($mock_directory, 'http%3A%2F%2Fexample.com%2FFIXTURE');
# this fixture content is not ACTUAL response of http://exapmle.com/FIXTURE !!!
my $fixture_content = file(__FILE__)->parent->file('assets','dummy_fixture')->slurp;
$mock_file->spew( $fixture_content );

# use T::W::S::UserAgent::OnlyOnce to test $ua->get called only once;
use_ok (
    'Test::WWW::Stub',
    fixture => {
        cache_dir => $mock_directory,
        ua_class => 'Test::WWW::Stub::UserAgent::OnlyOnce',
    }
);

{
    # force set 'WWW_STUB_ENABLE_CAPTURE' to 0 to prevent from unexpected behavior
    $ENV{WWW_STUB_ENABLE_CAPTURE} = 0;
    my $guard = Test::WWW::Stub->register('http://example.com/STUB', [200, [], ['okay']]);

    my $stubbed_res = ua->get('http://example.com/STUB');
    is $stubbed_res->content, 'okay', q|Feature::Fixture doesn't affect T::W::Stub->register|;

    my $fixture_res = ua->get('http://example.com/FIXTURE');
    ok $fixture_res->is_success, 'success';
    is $fixture_res->content, "This is a dummy response from file\n", 'content from fixture';

    my $ng_res = ua->get('http://example.com/NOT');
    ok $ng_res->is_error, 'only works when matched file exists';
}

{
    # Test capturing
    $ENV{WWW_STUB_ENABLE_CAPTURE} = 1;
    my $res_1st = ua->get('http://example.com/');
    ok $res_1st->is_success;
    is $res_1st->header('X-Test-Req-Uri'), 'http://example.com/';
    is $res_1st->content, "Response from Stubbed UserAgent\n", 'captured external response';

    my $res_2nd = ua->get('http://example.com/');
    ok $res_2nd->is_success;
    is $res_2nd->header('X-Test-Req-Uri'), 'http://example.com/';
    is $res_2nd->content, "Response from Stubbed UserAgent\n", 'captured response in file';

    my $raw_res = <<EOM;
200 OK
X-Test-Req-Uri: http://example.com/

Response from Stubbed UserAgent
EOM
    is file($mock_directory, 'http%3A%2F%2Fexample.com%2F')->slurp, $raw_res, 'captured re stored in file';
}

done_testing;

package Test::WWW::Stub::UserAgent;
use parent ('LWP::UserAgent');

package Test::WWW::Stub::UserAgent::OnlyOnce;
use parent ('LWP::UserAgent');
use HTTP::Response;
use Carp ();

sub _croak_if_already_requested {
    my ($self, $uri) = @_;

    $self->{_request_count} //= {};
    Carp::croak "GET $uri requested morethan once!" if $self->{_request_count}->{$uri};
    $self->{request_count}->{$uri} ++;
}

sub request {
    my ($self, $req) = @_;

    my $uri = $req->uri;
    $self->_croak_if_already_requested($uri);

    return HTTP::Response->new(
        200,
        '',
        ['X-Test-Req-Uri', "$uri"],
        "Response from Stubbed UserAgent\n",
    );
}

package main;
