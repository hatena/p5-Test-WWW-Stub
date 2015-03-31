requires 'perl', '5.008001';

requires 'LWP::Protocol::PSGI';
requires 'Plack::Request';
requires 'List::MoreUtils';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Test::Deep';
};

