use strict;
use warnings;
use Test::More;
use Test::Deep qw(cmp_deeply);

use LWP::UserAgent;

{
    package Test::WWW::Stub::Feature::Dummy;

    sub initialize {
        my ($class, %args) = @_;

        my $res = $args{res};
        my $guard = Test::WWW::Stub->register('http://example.com/featured/', $res);

        # keep guard in instance
        return +{ guard => $guard };
    }
}

use_ok (
    'Test::WWW::Stub',
    dummy => {
        res => [ 200, [], [ 'specified in args' ] ]
    },
);

my $res = LWP::UserAgent->new->get('http://example.com/featured/');
ok $res->is_success, 'stub registered in Feature::Dummy is working';
cmp_deeply $res->content, 'specified in args', 'args are properly passed to Feature::Dummy';

done_testing;
